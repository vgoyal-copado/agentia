import { createElement } from "lwc";
import WeatherDisplay from "c/weatherDisplay";
import getCurrentWeather from "@salesforce/apex/WeatherDisplayController.getCurrentWeather";

jest.mock(
  "@salesforce/apex/WeatherDisplayController.getCurrentWeather",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

describe("c-weather-display", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function flushPromises() {
    return Promise.resolve();
  }

  it("shows validation message when city is blank", async () => {
    const element = createElement("c-weather-display", { is: WeatherDisplay });
    document.body.appendChild(element);

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("Enter a city name");
    expect(getCurrentWeather).not.toHaveBeenCalled();
  });

  it("shows weather details when lookup succeeds", async () => {
    getCurrentWeather.mockResolvedValue({
      success: true,
      cityName: "London",
      condition: "clear sky",
      temperatureCelsius: 18.5,
      humidity: 62,
      windSpeedMetersPerSecond: 3.4
    });

    const element = createElement("c-weather-display", { is: WeatherDisplay });
    document.body.appendChild(element);

    const cityInput = element.shadowRoot.querySelectorAll("lightning-input")[0];
    cityInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "London" } })
    );
    element.shadowRoot.querySelector("lightning-button").click();

    await flushPromises();
    await flushPromises();

    expect(getCurrentWeather).toHaveBeenCalledWith({
      city: "London",
      countryCode: null
    });
    expect(element.shadowRoot.textContent).toContain("London");
    expect(element.shadowRoot.textContent).toContain("18.5°C");
    expect(element.shadowRoot.textContent).toContain("62%");
    expect(element.shadowRoot.textContent).toContain("3.4 m/s");
  });

  it("shows friendly error when service returns an error", async () => {
    getCurrentWeather.mockResolvedValue({
      success: false,
      errorMessage: "No weather data found for the requested location."
    });

    const element = createElement("c-weather-display", { is: WeatherDisplay });
    document.body.appendChild(element);

    const cityInput = element.shadowRoot.querySelectorAll("lightning-input")[0];
    cityInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "InvalidCity" } })
    );
    element.shadowRoot.querySelector("lightning-button").click();

    await flushPromises();
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("No weather data found");
  });
});
