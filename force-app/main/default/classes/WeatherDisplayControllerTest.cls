@IsTest
private class WeatherDisplayControllerTest {
  private static final String SUCCESS_BODY = '{"coord":{"lon":-0.13,"lat":51.51},"weather":[{"id":800,"main":"Clear","description":"clear sky","icon":"01d"}],"base":"stations","main":{"temp":18.5,"feels_like":17.9,"temp_min":16.2,"temp_max":20.1,"pressure":1015,"humidity":62},"visibility":10000,"wind":{"speed":3.4,"deg":250},"clouds":{"all":0},"dt":1712246400,"sys":{"type":2,"id":2006017,"country":"GB","sunrise":1712229600,"sunset":1712278800},"timezone":3600,"id":2643743,"name":"London","cod":200}';

  @IsTest
  static void shouldReturnWeather_WhenCityIsValid() {
    Test.setMock(HttpCalloutMock.class, new WeatherHttpMock(200, SUCCESS_BODY));

    Test.startTest();
    WeatherService.WeatherResult result = WeatherDisplayController.getCurrentWeather(
      'London',
      'GB'
    );
    Test.stopTest();

    Assert.isTrue(
      result.success,
      'Controller should return a successful weather lookup.'
    );
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
  }

  @IsTest
  static void shouldReturnError_WhenCityIsBlank() {
    Test.startTest();
    WeatherService.WeatherResult result = WeatherDisplayController.getCurrentWeather(
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
      new WeatherHttpMock(404, '{"cod":"404","message":"city not found"}')
    );

    Test.startTest();
    WeatherService.WeatherResult result = WeatherDisplayController.getCurrentWeather(
      'InvalidCity',
      null
    );
    Test.stopTest();

    Assert.isFalse(
      result.success,
      'Controller should surface not-found errors from the service.'
    );
    Assert.areEqual(
      'No weather data found for the requested location.',
      result.errorMessage,
      'Not found responses should use a friendly message.'
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
}
