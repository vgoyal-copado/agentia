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
    } catch (System.CalloutException ex) {
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

  /**
   * Sends the HTTP request to the configured weather endpoint.
   * @param city City name for the lookup.
   * @param countryCode Optional ISO 3166 country code.
   * @param setting Active custom metadata configuration.
   * @return Raw HTTP response from the weather provider.
   */
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

  /**
   * Parses the weather provider HTTP response into a structured result.
   * @param response HTTP response from the weather provider.
   * @param result Result object to populate on success or failure.
   * @return Populated weather result.
   */
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

  /**
   * Validates that a city name was provided.
   * @param city City name to validate.
   * @return Error message when invalid, otherwise null.
   */
  private static String validateCity(String city) {
    if (String.isBlank(city)) {
      return ERROR_CITY_REQUIRED;
    }
    return null;
  }

  /**
   * Builds the location query string for the weather API.
   * @param city City name for the lookup.
   * @param countryCode Optional ISO 3166 country code.
   * @return Location query accepted by the weather provider.
   */
  private static String buildLocationQuery(String city, String countryCode) {
    String trimmedCity = city.trim();
    if (String.isBlank(countryCode)) {
      return trimmedCity;
    }
    return trimmedCity + ',' + countryCode.trim();
  }

  @TestVisible
  private static Weather_API_Setting__mdt settingOverride;

  /**
   * Returns the active weather API configuration from custom metadata.
   * @return Active setting record, or null when inactive or missing.
   */
  private static Weather_API_Setting__mdt getActiveSetting() {
    if (Test.isRunningTest() && settingOverride != null) {
      return settingOverride.Is_Active__c == true ? settingOverride : null;
    }

    Weather_API_Setting__mdt setting = Weather_API_Setting__mdt.getInstance(
      DEFAULT_SETTING
    );
    if (setting == null || setting.Is_Active__c != true) {
      return null;
    }
    return setting;
  }

  /**
   * Converts an untyped JSON value to Decimal.
   * @param value JSON value from the provider payload.
   * @return Decimal representation, or null when the value is null.
   */
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

  /**
   * Converts an untyped JSON value to Integer.
   * @param value JSON value from the provider payload.
   * @return Integer representation, or null when the value is null.
   */
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
    /** Whether the weather lookup succeeded. */
    @AuraEnabled
    public Boolean success { get; set; }
    /** Error details when the lookup fails. */
    @AuraEnabled
    public String errorMessage { get; set; }
    /** Resolved city name from the weather provider. */
    @AuraEnabled
    public String cityName { get; set; }
    /** Current temperature in Celsius when units=metric. */
    @AuraEnabled
    public Decimal temperatureCelsius { get; set; }
    /** Short weather condition description. */
    @AuraEnabled
    public String condition { get; set; }
    /** Relative humidity percentage. */
    @AuraEnabled
    public Decimal humidity { get; set; }
    /** Current wind speed in meters per second when units=metric. */
    @AuraEnabled
    public Decimal windSpeedMetersPerSecond { get; set; }

    /** Initializes a failed weather result. */
    public WeatherResult() {
      this.success = false;
    }
  }

  /**
   * Invocable input parameters for Flow and Agentforce.
   */
  public class InvocableRequest {
    /** City name to look up. */
    @InvocableVariable(
      label='City'
      description='City name to look up.'
      required=true
    )
    public String city;

    /** Optional ISO 3166 country code for disambiguation. */
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
    /** Whether the weather lookup succeeded. */
    @InvocableVariable(
      label='Success'
      description='Whether the weather lookup succeeded.'
    )
    public Boolean success;

    /** Error details when the lookup fails. */
    @InvocableVariable(
      label='Error Message'
      description='Error details when the lookup fails.'
    )
    public String errorMessage;

    /** Resolved city name from the weather provider. */
    @InvocableVariable(
      label='City Name'
      description='Resolved city name from the weather provider.'
    )
    public String cityName;

    /** Current temperature in Celsius when units=metric. */
    @InvocableVariable(
      label='Temperature (C)'
      description='Current temperature in Celsius when units=metric.'
    )
    public Decimal temperatureCelsius;

    /** Short weather condition description. */
    @InvocableVariable(
      label='Condition'
      description='Short weather condition description.'
    )
    public String condition;

    /** Relative humidity percentage. */
    @InvocableVariable(
      label='Humidity (%)'
      description='Relative humidity percentage.'
    )
    public Decimal humidity;

    /** Current wind speed in meters per second when units=metric. */
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
