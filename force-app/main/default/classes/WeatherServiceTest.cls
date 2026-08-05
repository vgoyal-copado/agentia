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
