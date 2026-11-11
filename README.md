# Subly

## Firebase offers and Android attribution

The sample host reads the `settings` JSON parameter from Firebase Remote
Config. Add the Android app's `google-services.json` to
`sample/android/app/`; the Google Services plugin is enabled automatically
when that file exists. A deployable template is provided at
`sample/remoteconfig.template.json`.

`offers` are sorted by ascending `priority`. When no valid primary offer is
available, `fallbackOffers` is used; when both are empty, the app displays an
error state. `openMode: "browser"` opens an external browser/Custom Tab and
all other values use the in-app WebView.

The root catalogue can be overridden by detected country:

```json
{
  "offers": [],
  "fallbackOffers": [],
  "countries": {
    "AM": {"offers": [], "fallbackOffers": []}
  }
}
```

`app_data.country` is the primary geo source for catalogue selection. Each
country block inside `settings.countries` can contain its own `offers` and
`fallbackOffers`; changing those values in Remote Config does not require an
app release. When `app_data.country` is `ZZ`, the native attribution country is
used as a fallback.

```json
{
  "countries": {
    "AM": {"offers": [], "fallbackOffers": []},
    "PH": {"offers": [], "fallbackOffers": []},
    "IN": {"offers": [], "fallbackOffers": []}
  }
}
```

Android resolves country in this order: a persisted manual phone-prefix
choice, SIM country, network country, then `ZZ`. Persist a confident manual
choice with `AttributionService.setManualCountry("AM")`.

On activity start, GAID and Firebase App Instance ID warm into native
SharedPreferences. Play Install Referrer is read once after a successful
connection and then kept for the installation lifetime. Offer clicks only
read this cache and append non-empty values as `aff_sub2` through `aff_sub5`.

Subly is a reusable, local-first Flutter package for tracking subscriptions,
reviewing recurring spending, and running everyday financial estimates.

## Run the app

```sh
cd sample
flutter run
```

The Android offer screen uses Hybrid Composition. To compare it with the
previous rendering mode, build from `sample` with:

```sh
flutter build apk --release --dart-define=OFFER_WEBVIEW_HYBRID_COMPOSITION=false
```

The sample host targets Android and iOS. All app data is stored locally with
`shared_preferences`; there is no account, backend, advertising, analytics, or
sensitive runtime permission.

## Public API

Import `package:subly/subly.dart` and render `const SublyApp()`. The package owns
its Material 3 theme, splash, first-launch onboarding, navigation, local data,
privacy policy, and terms screens.
