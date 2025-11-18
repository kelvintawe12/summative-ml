from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from fastapi.middleware.cors import CORSMiddleware
import joblib
import pandas as pd

app = FastAPI(title="Ranch Conservation Weight Gain Predictor")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load all files
model = joblib.load("best_model.pkl")
scaler = joblib.load("scaler.pkl")
features = joblib.load("feature_columns.pkl")
le_treat = joblib.load("le_treatment.pkl")
le_past = joblib.load("le_pasture.pkl")

class InputData(BaseModel):
    initial_weight: float = Field(..., ge=400, le=1200)
    days_grazed: int = Field(..., ge=60, le=180)
    year: int = Field(..., ge=2000, le=2030)
    treatment: str = Field(..., pattern="^(light|moderate|heavy)$")
    pasture: str = Field(..., pattern="^(15E|23E|23W)$")

@app.get("/")
def home():
    return {"message": "USDA Cattle Gain Prediction API - LIVE"}

@app.post("/predict")
def predict(data: InputData):
    try:
        treat_code = le_treat.transform([data.treatment.lower()])[0]
        pasture_code = le_past.transform([data.pasture])[0]
        
        df = pd.DataFrame([{
            'on_Weight': data.initial_weight,
            'Season.Days': data.days_grazed,
            'Year': data.year,
            'treatment_encoded': treat_code,
            'pasture_encoded': pasture_code
        }])[features]
        
        pred = model.predict(scaler.transform(df))[0]
        return {"predicted_weight_gain_lbs": round(float(pred), 1)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
