/**
 * PII Tokenizer - Protects personal data from entering model context
 *
 * Anthropic Best Practice: Tokenize PII before processing, detokenize after.
 * This prevents personal data from being sent to the model while allowing
 * the model to work with placeholders.
 *
 * Supported PII types:
 * - Email addresses
 * - Phone numbers
 * - OIB (Croatian personal ID)
 * - Credit card numbers
 * - IP addresses
 *
 * Usage:
 *   const tokenizer = new PIITokenizer();
 *   const safe = tokenizer.tokenize(unsafeData);
 *   // ... process with model ...
 *   const original = tokenizer.detokenize(modelOutput);
 */

interface TokenMap {
  [token: string]: string;
}

interface PIIPattern {
  name: string;
  pattern: RegExp;
  prefix: string;
}

export class PIITokenizer {
  private tokenMap: TokenMap = {};
  private reverseMap: TokenMap = {};
  private counter: number = 0;

  private patterns: PIIPattern[] = [
    {
      name: "email",
      pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
      prefix: "EMAIL",
    },
    {
      name: "phone",
      // Matches various phone formats: +385..., (01)..., 091...
      pattern:
        /(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}/g,
      prefix: "PHONE",
    },
    {
      name: "oib",
      // Croatian OIB: 11 digits
      pattern: /\b\d{11}\b/g,
      prefix: "OIB",
    },
    {
      name: "card",
      // Credit card: 13-19 digits, possibly with spaces/dashes
      pattern: /\b(?:\d{4}[-\s]?){3,4}\d{1,4}\b/g,
      prefix: "CARD",
    },
    {
      name: "ip",
      // IPv4 addresses
      pattern:
        /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/g,
      prefix: "IP",
    },
  ];

  /**
   * Tokenize PII in the given data
   * @param data - String or object containing potential PII
   * @returns Tokenized version with PII replaced by tokens
   */
  tokenize(data: string | object): string | object {
    if (typeof data === "string") {
      return this.tokenizeString(data);
    }

    if (typeof data === "object" && data !== null) {
      return this.tokenizeObject(data);
    }

    return data;
  }

  /**
   * Detokenize - restore original PII values
   * @param data - Tokenized string or object
   * @returns Original data with PII restored
   */
  detokenize(data: string | object): string | object {
    if (typeof data === "string") {
      return this.detokenizeString(data);
    }

    if (typeof data === "object" && data !== null) {
      return this.detokenizeObject(data);
    }

    return data;
  }

  /**
   * Get current token map for debugging/logging
   */
  getTokenMap(): TokenMap {
    return { ...this.tokenMap };
  }

  /**
   * Clear all token mappings
   */
  clear(): void {
    this.tokenMap = {};
    this.reverseMap = {};
    this.counter = 0;
  }

  private tokenizeString(str: string): string {
    let result = str;

    for (const { pattern, prefix } of this.patterns) {
      result = result.replace(pattern, (match) => {
        // Check if already tokenized
        if (this.reverseMap[match]) {
          return this.reverseMap[match];
        }

        // Create new token
        const token = `[${prefix}_${++this.counter}]`;
        this.tokenMap[token] = match;
        this.reverseMap[match] = token;
        return token;
      });
    }

    return result;
  }

  private detokenizeString(str: string): string {
    let result = str;

    for (const [token, original] of Object.entries(this.tokenMap)) {
      result = result.replace(new RegExp(this.escapeRegex(token), "g"), original);
    }

    return result;
  }

  private tokenizeObject(obj: object): object {
    const result: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === "string") {
        result[key] = this.tokenizeString(value);
      } else if (typeof value === "object" && value !== null) {
        result[key] = this.tokenizeObject(value);
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  private detokenizeObject(obj: object): object {
    const result: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === "string") {
        result[key] = this.detokenizeString(value);
      } else if (typeof value === "object" && value !== null) {
        result[key] = this.detokenizeObject(value);
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
}

// CLI interface for bash wrapper
if (require.main === module) {
  const tokenizer = new PIITokenizer();
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error("Usage: pii-tokenizer.ts <tokenize|detokenize> <data>");
    process.exit(1);
  }

  const [action, ...dataParts] = args;
  const data = dataParts.join(" ");

  switch (action) {
    case "tokenize":
      console.log(tokenizer.tokenize(data));
      break;
    case "detokenize":
      console.log(tokenizer.detokenize(data));
      break;
    default:
      console.error(`Unknown action: ${action}`);
      process.exit(1);
  }
}

export default PIITokenizer;
