import { LightningElement } from "lwc";
import getCurrentWeather from "@salesforce/apex/WeatherDisplayController.getCurrentWeather";

export default class WeatherDisplay extends LightningElement {
  city = "";
  countryCode = "";
  isLoading = false;
  errorMessage;
  weatherResult;

  get hasWeatherResult() {
    return this.weatherResult?.success === true;
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get temperatureDisplay() {
    if (this.weatherResult?.temperatureCelsius == null) {
      return "";
    }
    return `${this.weatherResult.temperatureCelsius}°C`;
  }

  get humidityDisplay() {
    if (this.weatherResult?.humidity == null) {
      return "";
    }
    return `${this.weatherResult.humidity}%`;
  }

  get windSpeedDisplay() {
    if (this.weatherResult?.windSpeedMetersPerSecond == null) {
      return "";
    }
    return `${this.weatherResult.windSpeedMetersPerSecond} m/s`;
  }

  handleCityChange(event) {
    this.city = event.detail.value;
  }

  handleCountryChange(event) {
    this.countryCode = event.detail.value;
  }

  handleSearch() {
    this.errorMessage = undefined;
    this.weatherResult = undefined;

    const trimmedCity = (this.city || "").trim();
    if (!trimmedCity) {
      this.errorMessage = "Enter a city name to search for weather.";
      return;
    }

    this.isLoading = true;
    getCurrentWeather({
      city: trimmedCity,
      countryCode: this.countryCode || null
    })
      .then((result) => {
        if (result.success) {
          this.weatherResult = result;
        } else {
          this.errorMessage =
            result.errorMessage ||
            "Unable to retrieve weather for that location.";
        }
      })
      .catch(() => {
        this.errorMessage =
          "Something went wrong while fetching weather. Please try again.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }
}
