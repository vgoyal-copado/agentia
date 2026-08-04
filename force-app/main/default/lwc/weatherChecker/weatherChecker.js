import { LightningElement } from 'lwc';
import getWeatherForComponent from '@salesforce/apex/WeatherService.getWeatherForComponent';

export default class WeatherChecker extends LightningElement {
    city = '';
    countryCode = '';
    weather;
    errorMessage;
    isLoading = false;

    get hasWeather() {
        return this.weather && this.weather.success;
    }

    handleCityChange(event) {
        this.city = event.target.value;
    }

    handleCountryCodeChange(event) {
        this.countryCode = event.target.value;
    }

    async handleGetWeather() {
        this.errorMessage = undefined;
        this.weather = undefined;

        if (!this.city || !this.city.trim()) {
            this.errorMessage = 'City name is required.';
            return;
        }

        this.isLoading = true;
        try {
            const result = await getWeatherForComponent({
                city: this.city.trim(),
                countryCode: this.countryCode ? this.countryCode.trim() : null
            });

            if (result.success) {
                this.weather = result;
            } else {
                this.errorMessage = result.errorMessage;
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unable to retrieve weather data.';
    }
}
