Sustainable Ranch — Cattle Weight Gain Predictor

Mission (short)
- Provide ranchers a quick, data-driven estimate of cattle weight gain for different grazing treatments and pastures, using USDA CPER data to inform sustainable grazing decisions.

Public API (for automated tests)
- Swagger UI (public, tests use this): https://summative-ml-hliu.onrender.com/docs
- The `/predict` POST endpoint accepts JSON and returns `predicted_weight_gain_lbs`. Automated tests will use the public Swagger URL — do NOT use localhost for submission.

Demo
- YouTube demo (≤ 5 minutes): <INSERT_YOUTUBE_URL_HERE>

Live app
- Flutter Web App: https://kelvintawe12.github.io/summative-ml/

Official Dataset Source
- *USDA Agricultural Research Service* — LTAR Network, Central Plains Experimental Range
- Dataset (official):
  https://agdatacommons.nal.usda.gov/articles/dataset/Data_from_USDA_ARS_Central_Plains_Experimental_Range_CPER_near_Nunn_CO_Cattle_weight_gains_managed_with_light_moderate_and_heavy_grazing_intensities/25217282?file=44540186

Downloaded data (Colab & Drive)
- I initially ran experiments in Google Colab. To avoid runtime errors when reproducing the notebook locally, I copied the required CSV(s) to a Google Drive share. If you want to run the Colab notebook or reproduce the preprocessing locally, download the working data from this Drive location:

  https://drive.google.com/uc?id=1LLTrZiCAuPTpQUNWKVteyZzcJ-Zews6x

Quick features
- Random Forest model packaged for serving (best performer)
- FastAPI backend with Pydantic validation and `/health` endpoint
- Flutter app: input form, persistent history, charts, export/share

How to run the Flutter mobile/web app
1) Ensure Flutter is installed and `flutter` is on your PATH (stable channel). See https://flutter.dev/docs/get-started/install

2) Run on Chrome (web):
```powershell
cd Ranhop-flutterAPP
flutter pub get
flutter run -d chrome
```

3) Run on Android/emulator:
```powershell
cd Ranhop-flutterAPP
flutter pub get
flutter devices
flutter run
```

Notes
- To change the API target (for local testing), edit `Ranhop-flutterAPP/lib/services/predict_service.dart` and update the `baseUrl` constant.
- If running the API locally, ensure `API/` contains the model artifact files: `best_model.pkl`, `scaler.pkl`, `feature_columns.pkl`, `le_treatment.pkl`, `le_pasture.pkl`.

Contact / Support
- If you want me to insert the YouTube link or the Google Drive link into this README and/or update the Flutter app base URL, paste the links and I will update the repo.


Mission / Problem (short)
- Provide ranchers with a quick, data-driven estimate of cattle weight gain under different grazing treatments and pastures, using USDA CPER data to inform sustainable grazing decisions.

Public API (for automated tests)
- Swagger UI (public, tests use this): https://summative-ml-hliu.onrender.com/docs
- The `/predict` POST endpoint accepts JSON inputs and returns `predicted_weight_gain_lbs`. Use the Swagger UI above to exercise the endpoint (do NOT use localhost when submitting tests).

YouTube demo (≤ 5 minutes)
- Demo video: <INSERT_YOUTUBE_URL_HERE>  
  (Replace the placeholder above with a publicly accessible YouTube link of at most 5 minutes.)

Run the mobile/web app (Flutter)
1. Prerequisites
   - Install Flutter (stable) and enable the desired platforms (web, Android or iOS). See https://flutter.dev/docs/get-started/install.
   - From PowerShell on Windows, enable script execution if required and ensure `flutter` is on your PATH.

2. Run on Chrome (web quick test)
```powershell
cd Ranhop-flutterAPP
flutter pub get
flutter run -d chrome
```

3. Run on an Android device/emulator
```powershell
cd Ranhop-flutterAPP
flutter pub get
# list devices
flutter devices
# run on the target device id or default emulator
flutter run
```

4. Important configuration notes
- The Flutter app calls the public prediction API. To point the app to a different endpoint (for local testing), edit `Ranhop-flutterAPP/lib/services/predict_service.dart` and update the `baseUrl` or host constant. For automated grading, keep the base URL pointing to the public Swagger URL domain above.
- When running the API locally, ensure model artifact files exist in `API/` (`best_model.pkl`, `scaler.pkl`, `feature_columns.pkl`, `le_treatment.pkl`, `le_pasture.pkl`). The hosted API already has these artifacts.

Contact / Troubleshooting
- If the Swagger UI is unreachable, verify the public URL in the "Public API" section. If you need me to update the YouTube link or the API URL in the Flutter app, provide the link or new URL and I will update the repo.

Author: Kelvin Tawe — November 2025
# Sustainable Ranch Cattle Weight Gain Predictor – Kelvin Tawe

**Mission**: Help ranchers choose light grazing using real USDA CPER data → highest profit + wildlife conservation.

### Live Links
- **Public API (Swagger UI)**: https://summative-ml-hliu.onrender.com/docs
- **Flutter Web App (works on any phone/laptop)**: https://kelvintawe12.github.io/summative-ml/
Sustainable Ranch Cattle Weight Gain Predictor — Kelvin Tawe

Mission (short)
- Provide ranchers a quick, data-driven estimate of cattle weight gain for different grazing treatments and pastures using USDA CPER data. Inform sustainable grazing choices while balancing production and conservation.

Public API (used for automated tests)
- Swagger UI (public, tests use this): https://summative-ml-hliu.onrender.com/docs
- The grader will use the public Swagger UI to POST to `/predict`. The endpoint expects JSON and returns `predicted_weight_gain_lbs`. Do NOT use localhost in the submission — use the public URL above.

Demo
- YouTube demo (≤ 5 minutes): <INSERT_YOUTUBE_URL_HERE>


Live app
- Flutter Web App: https://kelvintawe12.github.io/summative-ml/

### Official Dataset Source
*USDA Agricultural Research Service*  
Long-Term Agroecosystem Research (LTAR) Network – Central Plains Experimental Range  
https://agdatacommons.nal.usda.gov/articles/dataset/Data_from_USDA_ARS_Central_Plains_Experimental_Range_CPER_near_Nunn_CO_Cattle_weight_gains_managed_with_light_moderate_and_heavy_grazing_intensities/25217282?file=44540186

Quick features
- Random Forest model packaged for serving (best performer during evaluation)
- FastAPI backend with Pydantic validation and a `/health` endpoint
- Flutter app: input form, history (persisted), charts, export/share utilities

How to run the Flutter mobile/web app
1) Ensure Flutter is installed and `flutter` is on your PATH. See https://flutter.dev/docs/get-started/install

2) Run on Chrome (web):
```powershell
cd Ranhop-flutterAPP
flutter pub get
flutter run -d chrome
```

3) Run on Android/emulator:
```powershell
cd Ranhop-flutterAPP
flutter pub get
flutter devices
flutter run
```

Notes
- To change the API target (for local testing), edit `Ranhop-flutterAPP/lib/services/predict_service.dart` and update the `baseUrl` constant.
- If running the API locally, make sure `API/` contains the model artifact files: `best_model.pkl`, `scaler.pkl`, `feature_columns.pkl`, `le_treatment.pkl`, `le_pasture.pkl`.

Contact / Support
- If you want me to insert your YouTube link or update the app base URL to the public API automatically, paste the link or new base URL and I will update the repo.

Author: Kelvin Tawe — November 2025
