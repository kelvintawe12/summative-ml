from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from fastapi.middleware.cors import CORSMiddleware
import joblib
import pandas as pd
import uvicorn

app = FastAPI(title="Ranch Conservation Weight Gain Predictor", version="1.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

model = joblib.load("best_model.pkl")
scaler = joblib.load("scaler.pkl")
features = joblib.load("feature_columns.pkl")
le_treat = joblib.load("le_treatment.pkl")
le_past = joblib.load("le_pasture.pkl")

class InputData(BaseModel):
    initial_weight: float = Field(..., ge=400, le=1200)
    days_grazed: int = Field(..., ge=60, le=180)
    year: int = Field(..., ge=2000, le=2030)
    treatment: str = Field(..., regex="^(light|moderate|heavy)$")
    pasture: str = Field(..., regex="^(15E|23E|23W)$")

@app.get("/")
def home():
    return {"message": "Welcome! Go to /docs for Swagger UI"}

@app.post("/predict")
def predict(data: InputData):
    try:
        treat_code = le_treat.transform([data.treatment.lower()])[0]
        pasture_code = le_past.transform([data.pasture])[0]
        
        input_df = pd.DataFrame([{
            'on_Weight': data.initial_weight,
            'Season.Days': data.days_grazed,
            'Year': data.year,
            'treatment_encoded': treat_code,
            'pasture_encoded': pasture_code
        }])[features]
        
        pred = model.predict(scaler.transform(input_df))[0]
        return {"predicted_weight_gain_lbs": round(float(pred), 1)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
