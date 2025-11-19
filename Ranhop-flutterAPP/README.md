# Sustainable Ranch — Cattle Weight Gain Predictor

*Mission *  

Help ranchers quickly estimate cattle weight gain under light, moderate, and heavy grazing using real USDA long-term research data from the Central Plains Experimental Range (CPER), promoting light grazing for maximum profit and wildlife conservation.

*Dataset & Source*  
USDA ARS – Central Plains Experimental Range (CPER), Nunn, Colorado  
Cattle weight gains managed with light, moderate and heavy grazing intensities (2000–2019)  
Permanent link: https://agdatacommons.nal.usda.gov/articles/dataset/Data_from_USDA_ARS_Central_Plains_Experimental_Range_CPER_near_Nunn_CO_Cattle_weight_gains_managed_with_light_moderate_and_heavy_grazing_intensities/25217282  
Original file: LTGI_2000-2019_all_weights_published.csv (cleaned version included as cattle_weights.csv)

*Public API Endpoint*  
Swagger UI (public, used for grading): https://summative-ml-hliu.onrender.com/docs  

*All Endpoints*  
- *GET /* → Home page (welcome message)  
- *GET /health* → Returns {"status": "healthy", "model": "RandomForest", "ready": true}  
- *POST /predict* → Returns {"predicted_weight_gain_lbs": ...}  

*YouTube Demo Video *  
<MY-RECORDED-YOUTUBE_LINK>


```powershell
flutter create .
```

This generates platform-specific files (`android/`, `ios/`, etc.).

3. Get packages:

```powershell
flutter pub get
```

4. Run the app (choose an emulator or device):

```powershell
flutter run
```

Notes

- The app posts to `https://summative-ml-hliu.onrender.com/predict`. 
- To create a release build:
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios` (on macOS)

