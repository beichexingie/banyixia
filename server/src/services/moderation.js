import { config } from '../config.js';

const DEFAULT_FORBIDDEN_WORDS = [
  '毒品',
  '赌博',
  '博彩',
  '代孕',
  '卖淫',
  '嫖娼',
  '枪支',
  '诈骗',
  '洗钱',
  '裸聊',
  '色情',
  '约炮',
  '法轮功',
];

function normalizeText(value) {
  return value
      ?.toString()
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/[^\p{L}\p{N}\u4e00-\u9fa5]+/gu, '') ?? '';
}

export function reviewText(text, { field = '内容' } = {}) {
  if (!config.moderationEnabled) {
    return { passed: true, hits: [] };
  }

  const normalizedText = normalizeText(text);
  if (!normalizedText) {
    return { passed: true, hits: [] };
  }

  const forbiddenWords = [
    ...DEFAULT_FORBIDDEN_WORDS,
    ...config.moderationForbiddenWords,
  ];
  const hits = forbiddenWords
      .map((word) => word.trim())
      .filter((word) => word.length > 0)
      .filter((word, index, list) => list.indexOf(word) === index)
      .filter((word) => normalizedText.includes(normalizeText(word)));

  return {
    passed: hits.length === 0,
    field,
    hits,
  };
}

export function assertTextAllowed(text, { field = '内容' } = {}) {
  const result = reviewText(text, { field });
  if (!result.passed) {
    const error = new Error(`${field}包含违禁词，请修改后再提交`);
    error.statusCode = 400;
    error.moderationHits = result.hits;
    throw error;
  }
}

export function assertPayloadAllowed(payload, fields) {
  for (const field of fields) {
    const value = payload?.[field.key];
    if (value == null || value === '') continue;
    assertTextAllowed(value, { field: field.label });
  }
}
