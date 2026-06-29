from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    mean_absolute_error,
    precision_recall_fscore_support,
    r2_score,
)
from sklearn.model_selection import train_test_split

try:
    from xgboost import XGBClassifier
except Exception:  # pragma: no cover
    XGBClassifier = None

LABEL_ORDER = ["VERDE", "AMARILLO", "ROJO"]
LABEL_TO_ID = {label: index for index, label in enumerate(LABEL_ORDER)}
ID_TO_LABEL = {index: label for label, index in LABEL_TO_ID.items()}

# IMPORTANT: risk_percentage is NOT used as an input feature for classification,
# because risk_label is derived from it. Using it would create target leakage.
FEATURE_COLUMNS = [
    "age_months",
    "reading_items",
    "phonology_items",
    "reading_correct_first_attempt",
    "phonology_correct_first_attempt",
    "reading_error_rate",
    "phonology_error_rate",
    "avg_response_time_ms",
    "wrong_taps_total",
    "drag_drop_errors",
    "high_complexity_errors",
]


def load_dataset(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)

    required = set(FEATURE_COLUMNS + ["risk_label", "risk_percentage"])
    missing = sorted(required - set(df.columns))
    if missing:
        raise ValueError(f"Missing required columns in dataset: {missing}")

    unknown_labels = sorted(set(df["risk_label"]) - set(LABEL_ORDER))
    if unknown_labels:
        raise ValueError(f"Unknown labels: {unknown_labels}. Expected: {LABEL_ORDER}")

    return df


def split_dataset(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
    if "dataset_split" in df.columns and {"train", "test"}.issubset(set(df["dataset_split"])):
        train_df = df[df["dataset_split"] == "train"].copy()
        test_df = df[df["dataset_split"] == "test"].copy()
        return train_df, test_df

    train_df, test_df = train_test_split(
        df,
        test_size=0.30,
        random_state=42,
        stratify=df["risk_label"],
    )
    return train_df.copy(), test_df.copy()


def evaluate_classifier(name: str, model, X_test: pd.DataFrame, y_test: pd.Series) -> Dict:
    y_pred = model.predict(X_test)

    precision_macro, recall_macro, f1_macro, _ = precision_recall_fscore_support(
        y_test,
        y_pred,
        average="macro",
        zero_division=0,
    )
    _, _, f1_weighted, _ = precision_recall_fscore_support(
        y_test,
        y_pred,
        average="weighted",
        zero_division=0,
    )

    cm = confusion_matrix(y_test, y_pred, labels=[0, 1, 2])

    return {
        "model": name,
        "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
        "precision_macro": round(float(precision_macro), 4),
        "recall_macro": round(float(recall_macro), 4),
        "f1_macro": round(float(f1_macro), 4),
        "f1_weighted": round(float(f1_weighted), 4),
        "confusion_matrix_labels": LABEL_ORDER,
        "confusion_matrix": cm.tolist(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Disly ML models.")
    parser.add_argument(
        "--data",
        type=Path,
        default=Path("data/processed/disly_dataset_160_students_synthetic.csv"),
        help="Path to the CSV dataset.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("ml/artifacts"),
        help="Output folder for trained models and metrics.",
    )
    args = parser.parse_args()

    output_dir = args.out
    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_dataset(args.data)
    train_df, test_df = split_dataset(df)

    X_train = train_df[FEATURE_COLUMNS]
    X_test = test_df[FEATURE_COLUMNS]
    y_train = train_df["risk_label"].map(LABEL_TO_ID).astype(int)
    y_test = test_df["risk_label"].map(LABEL_TO_ID).astype(int)

    results: Dict = {
        "dataset": {
            "total_records": int(len(df)),
            "train_records": int(len(train_df)),
            "test_records": int(len(test_df)),
            "label_distribution_total": df["risk_label"].value_counts().to_dict(),
            "label_distribution_train": train_df["risk_label"].value_counts().to_dict(),
            "label_distribution_test": test_df["risk_label"].value_counts().to_dict(),
            "features": FEATURE_COLUMNS,
            "note": "Synthetic/pilot technical-validation dataset. Not clinical validation.",
        },
        "classification": {},
        "regression": {},
    }

    rf_classifier = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        class_weight="balanced",
        max_depth=6,
        min_samples_leaf=2,
        n_jobs=1,
    )
    rf_classifier.fit(X_train, y_train)
    results["classification"]["RandomForest"] = evaluate_classifier(
        "RandomForest", rf_classifier, X_test, y_test
    )
    joblib.dump(rf_classifier, output_dir / "rf_risk_classifier.joblib")

    if XGBClassifier is not None:
        xgb_classifier = XGBClassifier(
            n_estimators=50,
            max_depth=3,
            learning_rate=0.05,
            subsample=0.9,
            colsample_bytree=0.9,
            objective="multi:softprob",
            num_class=3,
            eval_metric="mlogloss",
            random_state=42,
            n_jobs=1,
            tree_method="hist",
        )
        xgb_classifier.fit(X_train, y_train)
        results["classification"]["XGBoost"] = evaluate_classifier(
            "XGBoost", xgb_classifier, X_test, y_test
        )
        joblib.dump(xgb_classifier, output_dir / "xgb_risk_classifier.joblib")

    # Optional: a regressor can estimate risk_percentage. The app can then map
    # percentage to traffic-light labels with transparent thresholds.
    rf_regressor = RandomForestRegressor(
        n_estimators=100,
        random_state=42,
        max_depth=6,
        min_samples_leaf=2,
        n_jobs=1,
    )
    rf_regressor.fit(X_train, train_df["risk_percentage"])
    risk_pred = rf_regressor.predict(X_test)
    results["regression"]["RandomForestRegressor"] = {
        "target": "risk_percentage",
        "mae": round(float(mean_absolute_error(test_df["risk_percentage"], risk_pred)), 4),
        "r2": round(float(r2_score(test_df["risk_percentage"], risk_pred)), 4),
    }
    joblib.dump(rf_regressor, output_dir / "rf_risk_percentage_regressor.joblib")

    feature_importance = pd.DataFrame(
        {
            "feature": FEATURE_COLUMNS,
            "importance": rf_classifier.feature_importances_,
        }
    ).sort_values("importance", ascending=False)
    feature_importance.to_csv(output_dir / "feature_importance_rf.csv", index=False)

    (output_dir / "feature_columns.json").write_text(
        json.dumps(FEATURE_COLUMNS, indent=2),
        encoding="utf-8",
    )
    (output_dir / "label_mapping.json").write_text(
        json.dumps({"label_to_id": LABEL_TO_ID, "id_to_label": ID_TO_LABEL}, indent=2),
        encoding="utf-8",
    )
    (output_dir / "ml_metrics.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(json.dumps(results, indent=2, ensure_ascii=False))
    print(f"\nArtifacts saved to: {output_dir.resolve()}")


if __name__ == "__main__":
    main()
