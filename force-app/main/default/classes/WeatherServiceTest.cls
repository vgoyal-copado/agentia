@IsTest
private class WeatherServiceTest {
  private static String lastCapturedEndpoint;
  private static final String SUCCESS_BODY = '{"coord":{"lon":-0.13,"lat":51.51},"weather":[{"id":800,"main":"Clear","description":"clear sky","icon":"01d"}],"base":"stations","main":{"temp":18.5,"feels_like":17.9,"temp_min":16.2,"temp_max":20.1,"pressure":1015,"humidity":62},"visibility":10000,"wind":{"speed":3.4,"deg":250},"clouds":{"all":0},"dt":1712246400,"sys":{"type":2,"id":2006017,"country":"GB","sunrise":1712229600,"sunset":1712278800},"timezone":3600,"id":2643743,"name":"London","cod":200}';
  private static final String NOT_FOUND_BODY = '{"cod":"404","message":"city not found"}';

  @IsTest
  static void shouldReturnWeather_WhenCityIsValid() {
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, SUCCESS_BODY));

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isTrue(result.success, 'Expected a successful weather lookup.');
    Assert.areEqual(
      'London',
      result.cityName,
      'City name should match the provider response.'
    );
    Assert.areEqual(
      18.5,
      result.temperatureCelsius,
      'Temperature should be parsed from the API payload.'
    );
    Assert.areEqual(
      'clear sky',
      result.condition,
      'Condition should be parsed from the API payload.'
    );
    Assert.areEqual(
      62,
      result.humidity,
      'Humidity should be parsed from the API payload.'
    );
    Assert.areEqual(
      3.4,
      result.windSpeedMetersPerSecond,
      'Wind speed should be parsed from the API payload.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenCityIsBlank() {
    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      '   ',
      null
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Blank city input should fail validation.');
    Assert.isTrue(
      result.errorMessage == 'City name is required.',
      'Validation message should be user friendly.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenCityIsNotFound() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(404, NOT_FOUND_BODY)
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'InvalidCity',
      null
    );
    Test.stopTest();

    Assert.isFalse(
      result.success,
      'Unknown city should return an error result.'
    );
    Assert.isTrue(
      result.errorMessage ==
      'No weather data found for the requested location.',
      'Not found responses should use a friendly message.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenHttpStatusIsUnauthorized() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(401, '{"cod":401,"message":"Invalid API key"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(
      result.success,
      'Unauthorized API responses should fail gracefully.'
    );
    Assert.isTrue(
      result.errorMessage.contains('authentication failed'),
      'Authentication failures should mention credential configuration.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenHttpStatusIsServerError() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(503, '{"message":"Service unavailable"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Server errors should fail gracefully.');
    Assert.isTrue(
      result.errorMessage ==
      'Weather service is temporarily unavailable. Please try again later.',
      'Server failures should use a generic retry message.'
    );
  }

  @IsTest
  static void shouldReturnInvocableResults_WhenRequestsAreBulkified() {
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, SUCCESS_BODY));

    WeatherService.InvocableRequest request = new WeatherService.InvocableRequest();
    request.city = 'London';
    request.countryCode = 'GB';

    Test.startTest();
    List<WeatherService.InvocableResponse> responses = WeatherService.getCurrentWeatherInvocable(
      new List<WeatherService.InvocableRequest>{ request }
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      responses.size(),
      'Invocable method should return one response per request.'
    );
    Assert.isTrue(
      responses[0].success,
      'Invocable response should reflect a successful lookup.'
    );
    Assert.areEqual(
      'London',
      responses[0].cityName,
      'Invocable response should include resolved city name.'
    );
  }

  @IsTest
  static void shouldBuildEndpointWithCountryCode_WhenCountryIsProvided() {
    Test.setMock(HttpCalloutMock.class, new WeatherEndpointAssertMock());

    Test.startTest();
    WeatherService.getCurrentWeather('Paris', 'FR');
    Test.stopTest();

    Assert.isTrue(
      lastCapturedEndpoint.contains('q=Paris%2CFR'),
      'Country code should be appended to the location query.'
    );
  }

  @IsTest
  static void shouldReturnWeather_WhenComponentMethodIsCalled() {
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, SUCCESS_BODY));

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getWeatherForComponent(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isTrue(result.success, 'Component entry point should succeed.');
    Assert.areEqual('London', result.cityName, 'City name should be returned.');
  }

  @IsTest
  static void shouldReturnError_WhenConfigIsInactive() {
    WeatherService.settingOverride = new Weather_API_Setting__mdt(
      Endpoint_Path__c = '/weather',
      Units__c = 'metric',
      Is_Active__c = false
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Inactive config should fail gracefully.');
    Assert.areEqual(
      'Weather service is not active. Check Weather API Setting custom metadata.',
      result.errorMessage,
      'Inactive config should return a friendly message.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenHttpStatusIsForbidden() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(403, '{"cod":403,"message":"Forbidden"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(
      result.success,
      'Forbidden responses should fail gracefully.'
    );
    Assert.isTrue(
      result.errorMessage.contains('authentication failed'),
      'Forbidden responses should mention credential configuration.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenResponseBodyHasCod404() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(200, '{"cod":404,"message":"city not found"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'InvalidCity',
      null
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Cod 404 in body should fail gracefully.');
    Assert.areEqual(
      'No weather data found for the requested location.',
      result.errorMessage,
      'Cod 404 should use the not-found message.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenResponsePayloadIsInvalid() {
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(200, '{"cod":200,"name":"London"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Invalid payloads should fail gracefully.');
    Assert.areEqual(
      'Unable to parse weather data from the external service.',
      result.errorMessage,
      'Invalid payloads should use the parse error message.'
    );
  }

  @IsTest
  static void shouldReturnError_WhenResponseBodyIsBlank() {
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, ''));

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isFalse(result.success, 'Blank bodies should fail gracefully.');
    Assert.areEqual(
      'Weather service is temporarily unavailable. Please try again later.',
      result.errorMessage,
      'Blank bodies should use the unavailable message.'
    );
  }

  @IsTest
  static void shouldParseWeather_WhenWindDataIsMissing() {
    String bodyWithoutWind = '{"weather":[{"description":"clear sky"}],"main":{"temp":20,"humidity":55},"name":"Paris","cod":200}';
    Test.setMock(
      HttpCalloutMock.class,
      new WeatherHttpMock(200, bodyWithoutWind)
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'Paris',
      null
    );
    Test.stopTest();

    Assert.isTrue(result.success, 'Missing wind data should still succeed.');
    Assert.isNull(
      result.windSpeedMetersPerSecond,
      'Wind speed should be null when wind data is absent.'
    );
  }

  @IsTest
  static void shouldParseNumericValues_WhenPayloadUsesIntegerTypes() {
    String integerBody = '{"weather":[{"description":"sunny"}],"main":{"temp":21,"humidity":50},"wind":{"speed":2},"name":"Berlin","cod":200}';
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, integerBody));

    Test.startTest();
    WeatherService.WeatherResult result = WeatherService.getCurrentWeather(
      'Berlin',
      null
    );
    Test.stopTest();

    Assert.isTrue(result.success, 'Integer payload values should parse.');
    Assert.areEqual(21, result.temperatureCelsius, 'Temperature should parse.');
    Assert.areEqual(50, result.humidity, 'Humidity should parse.');
    Assert.areEqual(
      2,
      result.windSpeedMetersPerSecond,
      'Wind speed should parse.'
    );
  }

  @IsTest
  static void shouldBuildEndpointWithoutCountryCode_WhenCountryIsOmitted() {
    Test.setMock(HttpCalloutMock.class, new WeatherEndpointAssertMock());

    Test.startTest();
    WeatherService.getCurrentWeather('Tokyo', null);
    Test.stopTest();

    Assert.isTrue(
      lastCapturedEndpoint.contains('q=Tokyo'),
      'Endpoint should include only the city when country is omitted.'
    );
    Assert.isFalse(
      lastCapturedEndpoint.contains('%2C'),
      'Endpoint should not append a country delimiter when country is omitted.'
    );
  }

  private class WeatherHttpMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    WeatherHttpMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      response.setBody(body);
      response.setHeader('Content-Type', 'application/json');
      return response;
    }
  }

  private class WeatherEndpointAssertMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      lastCapturedEndpoint = req.getEndpoint();
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody(SUCCESS_BODY);
      response.setHeader('Content-Type', 'application/json');
      return response;
    }
  }
}
