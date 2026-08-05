/**
 * Retrieves current weather conditions for a city via OpenWeatherMap.
 * Callable from Apex, Flow, Agentforce, and Lightning components.
 */
public with sharing class WeatherService {
  private static final String NAMED_CREDENTIAL = 'callout:OpenWeatherMap';
  private static final String DEFAULT_SETTING = 'Default';
  private static final Integer CALLOUT_TIMEOUT_MS = 120000;
  private static final String ERROR_CITY_REQUIRED = 'City name is required.';
  private static final String ERROR_CONFIG_INACTIVE = 'Weather service is not active. Check Weather API Setting custom metadata.';
  private static final String ERROR_CITY_NOT_FOUND = 'No weather data found for the requested location.';
  private static final String ERROR_API_UNAVAILABLE = 'Weather service is temporarily unavailable. Please try again later.';
  private static final String ERROR_INVALID_RESPONSE = 'Unable to parse weather data from the external service.';

  /**
   * Returns current weather for a city.
   * @param city Required city name.
   * @param countryCode Optional ISO 3166 country code for disambiguation.
   * @return Structured weather result with success flag and error details.
   */
  public static WeatherResult getCurrentWeather(
    String city,
    String countryCode
  ) {
    WeatherResult result = new WeatherResult();
    result.success = false;

    String validationError = validateCity(city);
    if (validationError != null) {
      result.errorMessage = validationError;
      return result;
    }

    Weather_API_Setting__mdt setting = getActiveSetting();
    if (setting == null) {
      result.errorMessage = ERROR_CONFIG_INACTIVE;
      return result;
    }

    try {
      HttpResponse response = sendWeatherRequest(city, countryCode, setting);
      return parseResponse(response, result);
    } catch (WeatherServiceException ex) {
      result.errorMessage = ex.getMessage();
      return result;
    } catch (Exception ex) {
      result.errorMessage = ERROR_API_UNAVAILABLE;
      return result;
    }
  }

  /**
   * Flow and Agentforce entry point for weather lookups.
   * @param requests Bulkified request list from the calling automation.
   * @return One response per request with weather data or error details.
   */
  @InvocableMethod(
    label='Get Current Weather'
    description='Returns current weather conditions for a city or location.'
    category='Weather'
  )
  public static List<InvocableResponse> getCurrentWeatherInvocable(
    List<InvocableRequest> requests
  ) {
    List<InvocableResponse> responses = new List<InvocableResponse>();

    for (InvocableRequest request : requests) {
      InvocableResponse response = new InvocableResponse();
      WeatherResult weather = getCurrentWeather(
        request.city,
        request.countryCode
      );
      response.success = weather.success;
      response.errorMessage = weather.errorMessage;
      response.cityName = weather.cityName;
      response.temperatureCelsius = weather.temperatureCelsius;
      response.condition = weather.condition;
      response.humidity = weather.humidity;
      response.windSpeedMetersPerSecond = weather.windSpeedMetersPerSecond;
      responses.add(response);
    }

    return responses;
  }

  /**
   * Lightning component entry point for weather lookups.
   * @param city Required city name.
   * @param countryCode Optional ISO 3166 country code.
   * @return Weather result DTO serialized for UI consumption.
   */
  @AuraEnabled(cacheable=false)
  public static WeatherResult getWeatherForComponent(
    String city,
    String countryCode
  ) {
    return getCurrentWeather(city, countryCode);
  }

  @TestVisible
  private static HttpResponse sendWeatherRequest(
    String city,
    String countryCode,
    Weather_API_Setting__mdt setting
  ) {
    String locationQuery = buildLocationQuery(city, countryCode);
    String endpoint =
      NAMED_CREDENTIAL +
      setting.Endpoint_Path__c +
      '?q=' +
      EncodingUtil.urlEncode(locationQuery, 'UTF-8') +
      '&units=' +
      EncodingUtil.urlEncode(setting.Units__c, 'UTF-8');

    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('GET');
    request.setHeader('Accept', 'application/json');
    request.setTimeout(CALLOUT_TIMEOUT_MS);

    return new Http().send(request);
  }

  @TestVisible
  private static WeatherResult parseResponse(
    HttpResponse response,
    WeatherResult result
  ) {
    Integer statusCode = response.getStatusCode();
    String body = response.getBody();

    if (statusCode == 404) {
      result.errorMessage = ERROR_CITY_NOT_FOUND;
      return result;
    }

    if (statusCode == 401 || statusCode == 403) {
      throw new WeatherServiceException(
        'Weather API authentication failed. Verify the OpenWeatherMap credential.'
      );
    }

    if (statusCode >= 500) {
      throw new WeatherServiceException(ERROR_API_UNAVAILABLE);
    }

    if (statusCode < 200 || statusCode >= 300 || String.isBlank(body)) {
      throw new WeatherServiceException(ERROR_API_UNAVAILABLE);
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      body
    );
    Integer responseCode = toInteger(payload.get('cod'));
    if (responseCode != null && responseCode == 404) {
      result.errorMessage = ERROR_CITY_NOT_FOUND;
      return result;
    }

    Map<String, Object> mainData = (Map<String, Object>) payload.get('main');
    List<Object> weatherItems = (List<Object>) payload.get('weather');
    Map<String, Object> windData = (Map<String, Object>) payload.get('wind');

    if (mainData == null || weatherItems == null || weatherItems.isEmpty()) {
      throw new WeatherServiceException(ERROR_INVALID_RESPONSE);
    }

    Map<String, Object> weatherData = (Map<String, Object>) weatherItems[0];

    result.success = true;
    result.errorMessage = null;
    result.cityName = (String) payload.get('name');
    result.temperatureCelsius = toDecimal(mainData.get('temp'));
    result.humidity = toDecimal(mainData.get('humidity'));
    result.condition = (String) weatherData.get('description');
    result.windSpeedMetersPerSecond = windData == null
      ? null
      : toDecimal(windData.get('speed'));
    return result;
  }

  private static String validateCity(String city) {
    if (String.isBlank(city)) {
      return ERROR_CITY_REQUIRED;
    }
    return null;
  }

  private static String buildLocationQuery(String city, String countryCode) {
    String trimmedCity = city.trim();
    if (String.isBlank(countryCode)) {
      return trimmedCity;
    }
    return trimmedCity + ',' + countryCode.trim();
  }

  private static Weather_API_Setting__mdt getActiveSetting() {
    Weather_API_Setting__mdt setting = Weather_API_Setting__mdt.getInstance(
      DEFAULT_SETTING
    );
    if (setting == null || setting.Is_Active__c != true) {
      return null;
    }
    return setting;
  }

  private static Decimal toDecimal(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Decimal) {
      return (Decimal) value;
    }
    if (value instanceof Integer) {
      return Decimal.valueOf((Integer) value);
    }
    if (value instanceof Long) {
      return Decimal.valueOf((Long) value);
    }
    if (value instanceof Double) {
      return Decimal.valueOf((Double) value);
    }
    return Decimal.valueOf(String.valueOf(value));
  }

  private static Integer toInteger(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Integer) {
      return (Integer) value;
    }
    if (value instanceof Long) {
      return Integer.valueOf(String.valueOf(value));
    }
    if (value instanceof Decimal) {
      return ((Decimal) value).intValue();
    }
    return Integer.valueOf(String.valueOf(value));
  }

  /**
   * Structured weather response returned by the service.
   */
  public class WeatherResult {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String errorMessage { get; set; }
    @AuraEnabled
    public String cityName { get; set; }
    @AuraEnabled
    public Decimal temperatureCelsius { get; set; }
    @AuraEnabled
    public String condition { get; set; }
    @AuraEnabled
    public Decimal humidity { get; set; }
    @AuraEnabled
    public Decimal windSpeedMetersPerSecond { get; set; }

    public WeatherResult() {
      this.success = false;
    }
  }

  /**
   * Invocable input parameters for Flow and Agentforce.
   */
  public class InvocableRequest {
    @InvocableVariable(
      label='City'
      description='City name to look up.'
      required=true
    )
    public String city;

    @InvocableVariable(
      label='Country Code'
      description='Optional ISO 3166 country code for disambiguation.'
      required=false
    )
    public String countryCode;
  }

  /**
   * Invocable output parameters for Flow and Agentforce.
   */
  public class InvocableResponse {
    @InvocableVariable(
      label='Success'
      description='Whether the weather lookup succeeded.'
    )
    public Boolean success;

    @InvocableVariable(
      label='Error Message'
      description='Error details when the lookup fails.'
    )
    public String errorMessage;

    @InvocableVariable(
      label='City Name'
      description='Resolved city name from the weather provider.'
    )
    public String cityName;

    @InvocableVariable(
      label='Temperature (C)'
      description='Current temperature in Celsius when units=metric.'
    )
    public Decimal temperatureCelsius;

    @InvocableVariable(
      label='Condition'
      description='Short weather condition description.'
    )
    public String condition;

    @InvocableVariable(
      label='Humidity (%)'
      description='Relative humidity percentage.'
    )
    public Decimal humidity;

    @InvocableVariable(
      label='Wind Speed (m/s)'
      description='Current wind speed in meters per second when units=metric.'
    )
    public Decimal windSpeedMetersPerSecond;
  }

  /**
   * Domain-specific exception for weather integration failures.
   */
  public class WeatherServiceException extends Exception {
  }
}
