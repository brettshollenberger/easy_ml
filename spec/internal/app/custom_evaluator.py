import optuna
import pandas as pd
import numpy as np
from tqdm import tqdm
from bart_pipeline.services.router import ModelRouter
from catboost import Pool
from bart_pipeline.utils.project_root import project_root
import matplotlib.pyplot as plt
from ipywidgets import interact
from functools import partial
from sklearn.metrics import mean_absolute_error
from IPython.core.debugger import set_trace

tqdm.pandas()
# https://app.mode.com/nerdwallet/reports/4a710b2094d9

# TODO: Use real CPL rev per opp + integrate actual CPL rev per opp (as opposed to just CPA rev per opp)
class ModelEvaluator():
    @staticmethod
    def ok_for_production(dataloader, segment="standard", lead_scores=[10,11,12], model_type="regressor"):
        _, _, X_valid, _, _, y_valid = dataloader.prepare_for_training(keep_cols=["LOAN_APPLICATION_ID"])

        net_vs_standard, net_vs_cpl, scores = ModelEvaluator.evaluate(X_valid,
                                                                      y_valid,
                                                                      segment=segment,
                                                                      model_type=model_type,
                                                                      min_lead_score=min(lead_scores),
                                                                      max_lead_score=max(lead_scores))

        # Acceptable rev per opp is 50% of reference rev per opp, or $5, whichever is higher
        # That way we don't have to worry about getting too close to break even
        acceptable_rev_per_opp = np.max([(reference_rev_per_opp * 0.5), 10])

        # If the net vs CPL is lower, then CPL performs better than
        # standard. So we want to make sure Bart performs better than CPL,
        # and vice versa.
        if net_vs_cpl < net_vs_standard:
            check = "cpl"
            net = net_vs_cpl
        else:
            check = "standard"
            net = net_vs_standard

        pass_check = net > acceptable_rev_per_opp

        print(f"Net vs {check}: {net}")
        print(f"Reference rev per opp: {reference_rev_per_opp}")
        print(f"Acceptable rev per opp: {acceptable_rev_per_opp}")
        print(f"Pass check: {pass_check}")
        return pass_check

    @staticmethod
    def metric(lead_score_analysis, lead_score):
        improvement_vs_standard = lead_score_analysis["standard"][lead_score]['rev_per_opp_improvement']
        improvement_vs_cpl = lead_score_analysis["cpl"][lead_score]['rev_per_opp_improvement']
        standard_baseline = lead_score_analysis["standard"][lead_score]['baseline_rev_per_opp']
        cpl_baseline = lead_score_analysis["cpl"][lead_score]['baseline_rev_per_opp']

        if cpl_baseline > standard_baseline:
            result = improvement_vs_cpl
        else:
            result = improvement_vs_standard
        return result

    @staticmethod
    def evaluate(X_valid, y_valid, ys_valid_cpl, model=None, segment="standard", min_prediction=None, min_lead_score=8, max_lead_score=10, model_type="regressor"):
        df = ModelEvaluator.calculate_residuals(X_valid, y_valid, ys_valid_cpl, segment=segment, model=model, model_type=model_type)
        if "MIN_PREDICTION" in df.columns:
            min_prediction = df.groupby("LEAD_SCORE")["MIN_PREDICTION"].first().to_dict()

        net_vs_standard, lead_scores_vs_standard = ModelEvaluator.calculate_standard(df, min_prediction, min_lead_score, max_lead_score, model_type)
        net_vs_cpl, lead_scores_vs_cpl = ModelEvaluator.calculate_cpl(df, min_prediction, min_lead_score, max_lead_score, model_type)

        return net_vs_standard, net_vs_cpl, { "standard": lead_scores_vs_standard, "cpl": lead_scores_vs_cpl }

    @staticmethod
    def calculate_residuals(X_valid, y_valid, ys_valid_cpl, segment="standard", model=None, model_type="regressor"):
        ys = y_valid
        lead_scores = X_valid["LEAD_SCORE"].astype(int)
        lead_scores = lead_scores.reset_index(drop=True)

        df = pd.DataFrame()
        if model is None:
            print("Loading model router...")
            model = ModelRouter()
            prediction_method = "predict"
            predictions = getattr(model, prediction_method)(X_valid, decorated=True)
            df["MIN_PREDICTION"] = predictions["MIN_PREDICTION"]
            predictions = np.array(predictions["PREDICTION"])
        else:
            prediction_method = "predict"
            print(f"Predicting rows... {len(X_valid)}")
            cat_feature_idx = model.get_cat_feature_indices()
            feature_names = model.feature_names_
            cat_features = [feature_names[i] for i in cat_feature_idx]
            predict_pool = Pool(data=X_valid, label=ys, cat_features=cat_features)
            predictions = model.predict(predict_pool)

        if model_type == "classifier":
            ys_rev = pd.read_csv(project_root("ml/standard/train/data/ys_rev_valid.csv"))
            ys_rev["ys"].fillna(0, inplace=True)
            ys_rev = ys_rev["ys"]
            df["ACTUAL"] = ys_rev.astype(float)
            df["PREDICTED"] = predictions.astype(float)
            df["LEAD_SCORE"] = lead_scores
            df["CPL_REV"] = ys_valid_cpl
            df["CPL_REV"] = df["CPL_REV"].fillna(0)
            df["RESIDUALS"] = 0
        elif model_type == "regressor":
            predictions = predictions.clip(min=0)

            df["ACTUAL"] = ys.astype(float)
            df["PREDICTED"] = predictions.astype(float)
            df["LEAD_SCORE"] = lead_scores
            df["CPL_REV"] = ys_valid_cpl
            df["CPL_REV"] = df["CPL_REV"].fillna(0)
            df["RESIDUALS"] = df.apply(lambda x: np.abs(x["PREDICTED"] - x["ACTUAL"]), axis=1)

        return df

    @staticmethod
    def calculate_best_case(df):
        # Perfectly predicted
        # Sum sales rev + CPL rev - (sum all cpl rev)
        lead_score_values = {}
        for lead_score in range(8, 16):
            df = df.copy()
            df = df[df["LEAD_SCORE"] == lead_score]
            perfect_sales_rev = df[df["ACTUAL"] > 0]["REV"].sum()
            perfect_cpl_rev = df[df["ACTUAL"] == 0]["CPL_REV"].sum()
            base_cpl_rev = df["CPL_REV"].sum()
            perfect_rev_per_opp = (perfect_sales_rev + perfect_cpl_rev) / len(df)
            base_rev_per_opp = base_cpl_rev / len(df)
            lead_score_values[lead_score] = {
                "perfect_rev_per_opp": perfect_rev_per_opp,
                "baseline_rev_per_opp": base_rev_per_opp,
                "perfect_sales_rev": perfect_sales_rev,
                "perfect_cpl_rev": perfect_cpl_rev,
            }

        return lead_score_values

    @staticmethod
    def calculate_common(residuals, min_prediction, min_lead_score, max_lead_score, unique_computation, model_type="regressor"):
        total_net = 0
        lead_score_values = {}
        if min_prediction is None and model_type == "regressor":
            min_prediction = {lead_score: 300 for lead_score in range(
                min_lead_score, max_lead_score + 1)}

        for lead_score in range(min_lead_score, max_lead_score + 1):
            filtered = residuals[residuals["LEAD_SCORE"] == lead_score]

            if model_type == "classifier":
                worked_df = filtered[filtered["PREDICTED"] == True]
                non_worked = filtered[filtered["PREDICTED"] == False]
            elif model_type == "regressor":
                ls_min_pred = min_prediction[lead_score]
                worked_df = filtered[filtered["PREDICTED"] >= ls_min_pred]
                non_worked = filtered[filtered["PREDICTED"] < ls_min_pred]

            output = unique_computation(
                worked_df, non_worked, filtered, lead_score
            )

            lead_score_values[lead_score] = output
            lead_score_values[lead_score]["worked"] = len(worked_df)
            lead_score_values[lead_score]["non_worked"] = len(non_worked)
            lead_score_values[lead_score]["pct_filtered_out"] = len(non_worked) / len(filtered) if len(filtered) > 0 else 0

            total_net += output["rev_per_opp_improvement"]

        return total_net, lead_score_values

    @staticmethod
    def calculate_standard(residuals, min_prediction, min_lead_score, max_lead_score, model_type="regressor"):
        def unique_computation(worked_df, non_worked, filtered, lead_score):
            baseline = np.sum(filtered["ACTUAL"]) - (110 * len(filtered))
            cpl_upside = non_worked["CPL_REV"].sum()
            rev_opp_worked = np.sum(worked_df["ACTUAL"]) - (110 * len(worked_df))
            bart_made = cpl_upside + rev_opp_worked
            num_opps = len(filtered)
            bart_rev_per_opp = bart_made / num_opps
            baseline_rev_per_opp = baseline / num_opps
            net_rev_per_opp = bart_rev_per_opp - baseline_rev_per_opp
            return {
                "num_opps": num_opps, 
                "rev_per_opp_improvement": net_rev_per_opp,
                "bart_rev_per_opp": bart_rev_per_opp,
                "baseline_rev_per_opp": baseline_rev_per_opp,
            }

        return ModelEvaluator.calculate_common(residuals, min_prediction, min_lead_score, max_lead_score, unique_computation, model_type)

    @staticmethod
    def calculate_cpl(residuals, min_prediction, min_lead_score, max_lead_score, model_type="regressor"):
        def unique_computation(worked_df, non_worked, filtered, lead_score):
            cpl_only_baseline = filtered["CPL_REV"].sum()
            cpl_upside = non_worked["CPL_REV"].sum()
            rev_opp_worked = np.sum(worked_df["ACTUAL"]) - (110 * len(worked_df))
            bart_made = cpl_upside + rev_opp_worked
            num_opps = len(filtered)
            bart_rev_per_opp = bart_made / num_opps
            baseline_rev_per_opp = cpl_only_baseline / num_opps
            net_rev_per_opp = bart_rev_per_opp - baseline_rev_per_opp
            return {
                "num_opps": num_opps,
                "rev_per_opp_improvement": net_rev_per_opp,
                "bart_rev_per_opp": bart_rev_per_opp,
                "baseline_rev_per_opp": baseline_rev_per_opp
            }

        return ModelEvaluator.calculate_common(residuals, min_prediction, min_lead_score, max_lead_score, unique_computation, model_type)

    @staticmethod
    def objective(residuals, trial=None):
        min_prediction = trial.suggest_int("min_prediction", 100, 800)
        min_lead_score = trial.suggest_int("min_lead_score", 5, 8)
        max_lead_score = trial.suggest_int(
            "max_lead_score", min_lead_score, 10)
        return ModelEvaluator.calculate_financial_viability(residuals, min_prediction, min_lead_score, max_lead_score)

    @staticmethod
    def optimize(df, n_trials=500, date_cutoff="2023-08-01"):
        date_cutoff = "2023-08-01"
        filtered = df[df["CREATED_DATE"] >= date_cutoff]
        obj = partial(ModelEvaluator.objective, filtered)

        study = optuna.create_study(direction="maximize")
        study.optimize(obj, n_trials=n_trials)
        print(study.best_params)
        print(study.best_value)
        optuna.visualization.plot_param_importances(study)
        optuna.visualization.plot_contour(
            study, params=['minimum', 'min_lead_score', 'max_lead_score'])
        print("DONE!")
        return study
