/**
 * Aura-enabled controller for the Weather Display LWC.
 * Delegates weather lookups to WeatherService.
 */
public with sharing class WeatherDisplayController {
  /**
   * Returns current weather for the given city and optional country code.
   *
   * @param city Required city name.
   * @param countryCode Optional ISO 3166 country code.
   * @return Structured weather result from WeatherService.
   */
  @AuraEnabled
  public static WeatherService.WeatherResult getCurrentWeather(
    String city,
    String countryCode
  ) {
    return WeatherService.getCurrentWeather(city, countryCode);
  }
}
