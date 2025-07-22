import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px
import plotly.io as pio
from pathlib import Path

COMMON_LAYOUT_BASE = dict(
    template="plotly_white",
    margin=dict(t=30, l=0, r=30, b=0)
)

def get_common_style_maps(values, symbol_list=None):
    colors = px.colors.qualitative.Plotly
    symbol_list = symbol_list or ["circle", "square", "diamond", "cross", "x", "triangle-up", "triangle-down"]
    color_map = {v: colors[i % len(colors)] for i, v in enumerate(values)}
    symbol_map = {v: symbol_list[i % len(symbol_list)] for i, v in enumerate(values)}
    return color_map, symbol_map

def plot_summary(csv_path, output_dir, treatment_list, control, width=850, height=600):
    df = pd.read_csv(csv_path)
    df["bwfactor"] = df["bwfactor"].astype(str)
    metrics = [
        ("bias", "Bias", None),
        ("se", "Standard Deviation", None),
        ("rmse", "RMSE", None),
        ("coverage_rate", "Coverage Rate", 0.95)
    ]

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for treatment in treatment_list:
        df_sub = df[(df["treatment"] == treatment) & (df["control"] == control)]
        unique_N = sorted(df_sub["N"].unique())
        color_map, symbol_map = get_common_style_maps(unique_N)

        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=[m[1] for m in metrics],
            horizontal_spacing=0.1, vertical_spacing=0.125
        )

        for idx, (metric, _, yint) in enumerate(metrics):
            r, c = idx // 2 + 1, idx % 2 + 1
            for n_val in unique_N:
                df_n = df_sub[df_sub["N"] == n_val]
                if not df_n.empty:
                    fig.add_trace(
                        go.Scatter(
                            x=df_n["bwfactor"], y=df_n[metric],
                            mode="lines+markers",
                            name=f"N={n_val}" if idx == 0 else None,
                            legendgroup=f"N={n_val}", showlegend=(idx == 0),
                            marker=dict(color=color_map[n_val], symbol=symbol_map[n_val], size=10),
                            line=dict(color=color_map[n_val])
                        ), row=r, col=c
                    )
            if yint is not None:
                fig.add_hline(y=yint, line_dash="dash", line_color="black", row=r, col=c)

        fig.update_layout(
            width=width,
            height=height,
            legend_title="Sample Size (N)",
            legend=dict(orientation="h", yanchor="bottom", y=-0.15, xanchor="center", x=0.5),
            **COMMON_LAYOUT_BASE
        )
        fig.update_xaxes(title_text="Bandwidth Factor", row=2, col=1)
        fig.update_xaxes(title_text="Bandwidth Factor", row=2, col=2)
        fig.update_yaxes(title_text="Bias", row=1, col=1)
        fig.update_yaxes(title_text="Standard Deviation", row=1, col=2)
        fig.update_yaxes(title_text="RMSE", row=2, col=1)
        fig.update_yaxes(title_text="Coverage Rate", row=2, col=2)

        fig.write_image(str(output_dir / f"summary_t{treatment}_c{control}.png"), format="png", scale=2)

def plot_metrics(csv_path, output_dir, width=1000, height=325):
    df = pd.read_csv(csv_path)
    df["bwfactor"] = df["bwfactor"].astype(str)
    metrics = [
        ("bias", "Absolute Bias", None),
        ("se", "Standard Deviation", None),
        ("rmse", "RMSE", None),
        ("coverage_rate", "Coverage Rate", 0.95)
    ]
    treatment_values = sorted(df["treatment"].unique())
    N_values = sorted(df["N"].unique())
    color_map, symbol_map = get_common_style_maps(treatment_values)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for metric, title, yint in metrics:
        df_copy = df.copy()
        if metric == "bias":
            df_copy["bias"] = df_copy["bias"].abs()

        fig = make_subplots(
            rows=1, cols=3,
            subplot_titles=[f"N = {n}" for n in N_values],
            horizontal_spacing=0.05
        )
        for i, n in enumerate(N_values):
            for t in treatment_values:
                sub_df = df_copy[(df_copy["N"] == n) & (df_copy["treatment"] == t)]
                if not sub_df.empty:
                    fig.add_trace(
                        go.Scatter(
                            x=sub_df["bwfactor"], y=sub_df[metric],
                            mode="lines+markers",
                            name=f"Treatment={t}" if i == 0 else None,
                            legendgroup=f"Treatment={t}", showlegend=(i == 0),
                            marker=dict(symbol=symbol_map[t], size=10, color=color_map[t]),
                            line=dict(color=color_map[t], dash="solid", width=2)
                        ), row=1, col=i+1
                    )
            if yint is not None:
                fig.add_hline(y=yint, line_dash="dash", line_color="black", row=1, col=i+1)

        fig.update_layout(
            height=height, width=width,
            legend=dict(orientation="h", yanchor="bottom", y=-0.3, xanchor="center", x=0.5),
            **COMMON_LAYOUT_BASE
        )
        for j in range(1, 4):
            fig.update_xaxes(title_text="Bandwidth Factor", row=1, col=j)
            fig.update_yaxes(title_text=title, row=1, col=j, matches='y')

        fig.write_image(str(output_dir / f"{metric}.png"), format="png", scale=2)

def boxplot_centered_atet(csv_path, output_dir, width=1050, height=1050):
    df = pd.read_csv(csv_path)
    df["atet_dev"] = df["atet"] - df["true_effect"]
    df["bwfactor"] = pd.Categorical(df["bwfactor"], categories=sorted(df["bwfactor"].unique()), ordered=True)
    df["N"] = df["N"].astype(str)
    fig = px.box(
        df, x="treatment", y="atet_dev", color="N",
        facet_col="bwfactor", facet_col_wrap=2,
        points="outliers",
        labels={
            "treatment": "Treatment",
            "atet_dev": "ATET - True Effect",
            "N": "Sample Size (N)"
        },
        category_orders={
            "bwfactor": sorted(df["bwfactor"].unique()),
            "N": sorted(df["N"].unique())
        },
        color_discrete_sequence=px.colors.qualitative.Plotly
    )
    fig.add_hline(y=0, line_dash="dot", line_color="gray")
    fig.update_layout(
        width=width, height=height,
        legend_title="Sample Size (N)",
        legend=dict(orientation="h", yanchor="bottom", y=-0.1, xanchor="center", x=0.5),
        **COMMON_LAYOUT_BASE
    )
    fig.update_xaxes(tickmode="array", tickvals=[3, 4, 5, 6, 7], showticklabels=True)
    fig.update_yaxes(title_font=dict(size=12), tickfont=dict(size=10))
    fig.update_annotations(font=dict(size=12))

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    fig.write_image(str(output_dir / "boxplot_centered_atet.png"), format="png", scale=2)

if __name__ == "__main__":
    plot_summary(
        csv_path="./visualization/csv/summary.csv", 
        output_dir="./visualization/png", 
        treatment_list=[3, 4, 5, 6, 7], 
        control=2, 
        width=850, 
        height=600
    )
    plot_metrics(
        csv_path="./visualization/csv/summary.csv",
        output_dir="./visualization/png",
        width=1000,
        height=325
    )
    boxplot_centered_atet(
        csv_path="./visualization/csv/non_null_simulation_results.csv", 
        output_dir="./visualization/png", 
        width=1050, 
        height=1050
    )
