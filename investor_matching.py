import os
import pandas as pd
from openai import OpenAI

client = OpenAI(base_url="https://openrouter.ai/api/v1",api_key="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")

def get_user_input():
    print("\nEnter startup details:\n")

    sector = input("Sector (e.g., AgriTech, Fintech): ").strip().lower()
    stage = input("Stage (Seed / Series A / Series B): ").strip().lower()
    country = input("Country (e.g., India): ").strip().lower()
    description = input("Startup description: ").strip()

    return {
        "sector": sector,
        "stage": stage,
        "country": country,
        "description": description
    }

def filter_dataset(csv_path, user_input):
    df = pd.read_csv(csv_path)

    for col in ["sector", "stage", "city"]:
        df[col] = df[col].astype(str).str.lower()

    filtered_df = df[
        df["sector"].str.contains(user_input["sector"], na=False) &
        df["stage"].str.contains(user_input["stage"], na=False)
    ]

    return filtered_df

def build_llm_context(filtered_df, max_rows=25):
    context = ""

    for _, row in filtered_df.head(max_rows).iterrows():
        context += f"""
Startup Name: {row['startup_name']}
Sector: {row['sector']}
Stage: {row['stage']}
Description: {row['description']}
Investor: {row['investors']}
Amount Raised (USD): {row['amount_usd']}
---
"""
    return context.strip()

def get_top_investors_llm(context, user_input):
    prompt = f"""
You are an expert startup–investor matching system.

USER STARTUP DESCRIPTION:
"{user_input['description']}"

FILTER CONDITIONS:
- Sector: {user_input['sector']}
- Stage: {user_input['stage']}
- Geography: {user_input['country']}

PAST FUNDING DATA:
{context}

TASK:
1. Identify investors most relevant to the user's startup
2. Rank ONLY the TOP 3 investors
3. Assign a realistic matching percentage (70–95%)
4. Provide a short reason for each investor

STRICT OUTPUT FORMAT (NO EXTRA TEXT):

Top Investor Matches:

1. Investor Name – XX% match
   (Reason)

2. Investor Name – XX% match
   (Reason)

3. Investor Name – XX% match
   (Reason)
"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2
    )

    return response.choices[0].message.content

def main():
    CSV_PATH = "perfect_startup_funding.csv"  

    user_input = get_user_input()

    filtered_df = filter_dataset(CSV_PATH, user_input)

    if filtered_df.empty:
        print("\n❌ No startups found for given filters.")
        return

    context = build_llm_context(filtered_df)

    output = get_top_investors_llm(context, user_input)

    print("\n" + output)

if __name__ == "__main__":
    main()
