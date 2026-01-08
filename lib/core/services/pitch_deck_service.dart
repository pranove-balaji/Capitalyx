import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PitchDeckService {
  // Use OPENROUTER_API_KEY from .env
  String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? "";

  // 1. Extract Text from PDF
  // Note: syncfusion_flutter_pdf works on all platforms.
  Future<String> extractTextFromPdf(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.trim();
    } catch (e) {
      print('Error extracting PDF text: $e');
      throw Exception('Failed to extract text from PDF');
    }
  }

  // 2. Build Prompt (Logic from Python)
  String _buildPrompt(String deckText, String seedType, String investorType) {
    // Context dictionaries (Hardcoded as in user script)
    const seedTypeEval = {
      "pre-seed": {
        "focus": "Vision, problem clarity, and founder-market fit",
        "must_have": [
          "Clear and painful problem",
          "Founder insight or unfair advantage",
          "Early validation such as pilots, interviews, or waitlists",
          "Simple and believable solution"
        ],
        "nice_to_have": [
          "Clickable prototype or MVP",
          "Early partnerships",
          "Advisors with domain expertise"
        ],
        "red_flags": [
          "Vague problem statement",
          "Over-engineered solution",
          "Large financial projections without validation",
          "Unclear target customer"
        ],
        "traction_expectation":
            "Not required; qualitative validation is sufficient",
        "market_expectation": "High-level market size with clear target user",
        "funding_expectation": "Small raise with clear milestone-driven usage"
      },
      "seed": {
        "focus":
            "Early traction, product-market fit signals, and execution ability",
        "must_have": [
          "Live product or strong MVP",
          "Early user or revenue traction",
          "Clear use case and customer segment",
          "Credible market sizing (TAM/SAM/SOM)"
        ],
        "nice_to_have": [
          "Month-over-month growth metrics",
          "Initial paying customers",
          "Repeat usage or retention data"
        ],
        "red_flags": [
          "No measurable traction",
          "Unclear monetization strategy",
          "Inflated market numbers",
          "Vague go-to-market plan"
        ],
        "traction_expectation": "Early but measurable traction",
        "market_expectation": "Clear TAM/SAM/SOM with realistic assumptions",
        "funding_expectation": "Capital required to reach product-market fit"
      },
      "series-a": {
        "focus": "Scalability, growth efficiency, and market leadership",
        "must_have": [
          "Strong and consistent revenue growth",
          "Clear product-market fit",
          "Retention and cohort metrics",
          "Defined go-to-market strategy"
        ],
        "nice_to_have": [
          "Strong unit economics",
          "Defensible moat or differentiation",
          "Experienced leadership team"
        ],
        "red_flags": [
          "Weak or inconsistent growth",
          "Poor retention or high churn",
          "Unclear scaling strategy",
          "Lack of competitive differentiation"
        ],
        "traction_expectation": "Strong revenue and growth metrics",
        "market_expectation": "Large and defensible market opportunity",
        "funding_expectation":
            "Capital to scale aggressively and expand markets"
      }
    };

    const investorTypeEval = {
      "angel": {
        "focus": "Founder, vision, and storytelling",
        "must_have": [
          "Strong founding team",
          "Clear long-term vision",
          "Compelling personal insight into the problem",
          "Simple and understandable solution"
        ],
        "nice_to_have": [
          "Early users or pilots",
          "Advisor credibility",
          "Clear roadmap"
        ],
        "red_flags": [
          "Unclear founder roles",
          "Lack of passion or conviction",
          "Overly complex metrics",
          "Weak narrative"
        ],
        "traction_importance": "Low to medium",
        "decision_driver": "Belief in founders and vision"
      },
      "vc": {
        "focus": "Scale, returns, and defensibility",
        "must_have": [
          "Large addressable market",
          "Strong traction or growth signals",
          "Clear differentiation",
          "Scalable business model"
        ],
        "nice_to_have": [
          "Strong unit economics",
          "Clear exit potential",
          "Competitive moat"
        ],
        "red_flags": [
          "Small or unclear market",
          "Weak traction",
          "No competitive advantage",
          "Unclear funding ask"
        ],
        "traction_importance": "High",
        "decision_driver": "Market size and growth potential"
      },
      "corporate": {
        "focus": "Strategic alignment and integration",
        "must_have": [
          "Clear enterprise or B2B use case",
          "Strategic fit with corporate goals",
          "Potential for long-term partnership",
          "Technology differentiation"
        ],
        "nice_to_have": [
          "Enterprise pilots",
          "Existing corporate customers",
          "Integration readiness"
        ],
        "red_flags": [
          "No strategic alignment",
          "Unclear enterprise value proposition",
          "Consumer-only focus",
          "Immature technology"
        ],
        "traction_importance": "Medium",
        "decision_driver": "Strategic value and synergy"
      }
    };

    // Construct prompt string
    return """
You are an expert startup investor and professional pitch deck reviewer.

You MUST strictly follow the evaluation criteria provided below.
Do NOT invent expectations outside this context.

====================================
SEED STAGE EVALUATION CONTEXT
====================================
${jsonEncode(seedTypeEval[seedType.toLowerCase()] ?? {})}

====================================
INVESTOR TYPE EVALUATION CONTEXT
====================================
${jsonEncode(investorTypeEval[investorType.toLowerCase()] ?? {})}

====================================
PITCH DECK TEXT
====================================
$deckText

====================================
TASK
====================================
Analyze the pitch deck using ONLY the above evaluation context.

1. Identify whether the following sections are PRESENT and STRONG, PRESENT BUT WEAK, or MISSING:
   - Problem
   - Solution
   - Market
   - Traction
   - Team
   - Funding Ask

2. Evaluate each section based on:
   - Seed stage expectations
   - Investor type priorities

3. Flag any missing or weak sections as risks.

4. Generate clear, actionable suggestions that directly address the weaknesses.

====================================
OUTPUT FORMAT (FOLLOW EXACTLY)
====================================

Pitch Deck Feedback:

✔ Problem: <one short reason> 
✔ Solution: <one short reason>
⚠ Market: <what is missing or weak>
⚠ Traction: <what is missing or weak>
✔ Team: <one short reason>
❌ Funding Ask: <why it is missing or unclear>

Key Risks:
- <risk 1>
- <risk 2>
- <risk 3>

Suggestions:
- <actionable improvement 1>
- <actionable improvement 2>
- <actionable improvement 3>

====================================
STRICT RULES
====================================
- Use ✔ only if the section clearly meets expectations.
- Use ⚠ if the section exists but is weak or incomplete.
- Use ❌ only if the section is missing.
- Do NOT mention internal reasoning.
- Do NOT reference evaluation context explicitly.
- Keep feedback concise and investor-focused.
""";
  }

  // 3. Analyze Deck using OpenRouter
  Future<String> analyzeDeck(
      String text, String seedType, String investorType) async {
    final prompt = _buildPrompt(text, seedType, investorType);
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          // Optional but good for OpenRouter
          'HTTP-Referer': 'https://startup-app.com',
          'X-Title': 'Startup App',
        },
        body: jsonEncode({
          "model": "openai/gpt-4o-mini", // Using gpt-4o-mini via OpenRouter
          "messages": [
            {
              "role": "system",
              "content": "You are a strict pitch deck reviewer."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.2,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            "No analysis returned.";
      } else {
        print('OpenRouter Error: ${response.statusCode} - ${response.body}');
        return "Failed to analyze pitch deck. Please try again.";
      }
    } catch (e) {
      print('PitchDeckService Exception: $e');
      throw Exception('Failed to connect to AI service');
    }
  }
}
