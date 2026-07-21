import { config } from '../config.js';

const BLOCK_KEYWORDS = [
  '毒品',
  '冰毒',
  '海洛因',
  '大麻',
  '赌博',
  '博彩',
  '裸聊',
  '色情',
  '卖淫',
  '嫖娼',
  '代孕',
  '枪支',
  '洗钱',
  '诈骗',
  '法轮功',
];

const REVIEW_KEYWORDS = [
  '加微信',
  '微信',
  'vx',
  'v信',
  '微 信',
  'qq',
  '私下交易',
  '线下转账',
  '支付宝转我',
  '银行卡',
  '返现',
  '刷单',
  '上门',
  '陪睡',
  '特殊服务',
];

let greenClientPromise;

function normalizeText(value) {
  return value
      ?.toString()
      .toLowerCase()
      .replace(/[０-９]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0))
      .replace(/[ａ-ｚＡ-Ｚ]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0))
      .replace(/\s+/g, '')
      .replace(/[^\p{L}\p{N}\u4e00-\u9fa5]+/gu, '') ?? '';
}

function uniqueKeywords(words) {
  return words
      .map((word) => word?.toString().trim() ?? '')
      .filter(Boolean)
      .filter((word, index, list) => list.indexOf(word) === index);
}

function findHits(text, words) {
  const normalizedText = normalizeText(text);
  if (!normalizedText) return [];
  return uniqueKeywords(words).filter((word) => normalizedText.includes(normalizeText(word)));
}

function extractCloudSuggestion(response) {
  const body = response?.body ?? response;
  const data = body?.data ?? body?.Data ?? body;
  const result = Array.isArray(data?.result)
    ? data.result[0]
    : Array.isArray(data?.Result)
      ? data.Result[0]
      : data;
  const suggestion = (
    result?.suggestion ??
    result?.Suggestion ??
    result?.riskLevel ??
    result?.RiskLevel ??
    result?.risk_level ??
    ''
  ).toString().toLowerCase();
  const labels = [
    result?.label,
    result?.Label,
    result?.riskLabel,
    result?.RiskLabel,
    result?.riskTips,
    result?.RiskTips,
  ].filter(Boolean);
  if (['block', 'reject', 'high', 'danger'].includes(suggestion)) {
    return { action: 'block', labels };
  }
  if (['review', 'manual', 'medium', 'suspect', 'warning'].includes(suggestion)) {
    return { action: 'review', labels };
  }
  return { action: 'pass', labels };
}

async function getGreenClient() {
  if (greenClientPromise) return greenClientPromise;
  greenClientPromise = (async () => {
    const [
      openApiModule,
      greenModule,
    ] = await Promise.all([
      import('@alicloud/openapi-client'),
      import('@alicloud/green20220302'),
    ]);
    const Config = openApiModule.default?.Config ?? openApiModule.Config;
    const GreenClient = greenModule.default?.default ?? greenModule.default ?? greenModule.Client;
    return new GreenClient(new Config({
      accessKeyId: config.aliyunContentSafetyAccessKeyId,
      accessKeySecret: config.aliyunContentSafetyAccessKeySecret,
      endpoint: config.aliyunGreenEndpoint,
    }));
  })();
  return greenClientPromise;
}

function canUseAliyunModeration() {
  return Boolean(
    config.aliyunContentSafetyEnabled &&
    config.aliyunContentSafetyAccessKeyId &&
    config.aliyunContentSafetyAccessKeySecret,
  );
}

async function reviewTextByAliyun(text) {
  if (!canUseAliyunModeration()) {
    return { action: 'pass', source: 'aliyun_disabled', labels: [] };
  }
  try {
    const client = await getGreenClient();
    const serviceParameters = JSON.stringify({ content: text?.toString() ?? '' });
    if (typeof client.textModerationPlus === 'function') {
      const request = {
        service: config.aliyunTextModerationService,
        serviceParameters,
      };
      const response = await client.textModerationPlus(request);
      return { ...extractCloudSuggestion(response), source: 'aliyun_text_plus' };
    }
    if (typeof client.textModeration === 'function') {
      const request = {
        service: config.aliyunTextModerationService,
        serviceParameters,
      };
      const response = await client.textModeration(request);
      return { ...extractCloudSuggestion(response), source: 'aliyun_text' };
    }
    throw new Error('Aliyun Green SDK does not expose text moderation method');
  } catch (error) {
    if (config.aliyunContentSafetyFailOpen) {
      return {
        action: 'review',
        source: 'aliyun_error_fail_open',
        labels: [error.message],
      };
    }
    const serviceError = new Error(`内容安全服务调用失败: ${error.message}`);
    serviceError.statusCode = 503;
    throw serviceError;
  }
}

async function reviewImageByAliyun(imageUrl) {
  if (!canUseAliyunModeration()) {
    return { action: 'pass', source: 'aliyun_disabled', labels: [] };
  }
  try {
    const client = await getGreenClient();
    const serviceParameters = JSON.stringify({ imageUrl });
    if (typeof client.imageModeration === 'function') {
      const request = {
        service: config.aliyunImageModerationService,
        serviceParameters,
      };
      const response = await client.imageModeration(request);
      return { ...extractCloudSuggestion(response), source: 'aliyun_image' };
    }
    throw new Error('Aliyun Green SDK does not expose image moderation method');
  } catch (error) {
    if (config.aliyunContentSafetyFailOpen) {
      return {
        action: 'review',
        source: 'aliyun_error_fail_open',
        labels: [error.message],
      };
    }
    const serviceError = new Error(`图片安全服务调用失败: ${error.message}`);
    serviceError.statusCode = 503;
    throw serviceError;
  }
}

function combineActions(results) {
  if (results.some((item) => item.action === 'block')) return 'block';
  if (results.some((item) => item.action === 'review')) return 'review';
  return 'pass';
}

export async function reviewText(text, { field = '内容' } = {}) {
  if (!config.moderationEnabled) {
    return { action: 'pass', passed: true, reviewStatus: 'approved', hits: [], field };
  }

  const blockHits = findHits(text, [...BLOCK_KEYWORDS, ...config.moderationForbiddenWords]);
  if (blockHits.length > 0) {
    return {
      action: 'block',
      passed: false,
      reviewStatus: 'rejected',
      field,
      hits: blockHits,
      reason: `${field}包含禁止发布内容`,
      source: 'local_block',
    };
  }

  const reviewHits = findHits(text, REVIEW_KEYWORDS);
  const localResult = reviewHits.length > 0
    ? { action: 'review', source: 'local_review', labels: reviewHits }
    : { action: 'pass', source: 'local_pass', labels: [] };
  const cloudResult = await reviewTextByAliyun(text);
  const action = combineActions([localResult, cloudResult]);
  return {
    action,
    passed: action !== 'block',
    reviewStatus: action === 'review' ? 'pending' : 'approved',
    field,
    hits: [...reviewHits, ...(cloudResult.labels ?? [])],
    source: [localResult.source, cloudResult.source].join(','),
    reason: action === 'review' ? `${field}需要人工审核` : '',
  };
}

export async function reviewImage(imageUrl, { field = '图片' } = {}) {
  const cloudResult = await reviewImageByAliyun(imageUrl);
  const action = cloudResult.action;
  return {
    action,
    passed: action !== 'block',
    reviewStatus: action === 'review' ? 'pending' : 'approved',
    field,
    hits: cloudResult.labels ?? [],
    source: cloudResult.source,
    reason: action === 'review' ? `${field}需要人工审核` : '',
  };
}

export async function reviewPayload(payload, fields) {
  const results = [];
  for (const field of fields) {
    const value = payload?.[field.key];
    if (value == null || value === '') continue;
    results.push(await reviewText(value, { field: field.label }));
  }
  const action = combineActions(results);
  return {
    action,
    passed: action !== 'block',
    reviewStatus: action === 'review' ? 'pending' : 'approved',
    results,
    hits: results.flatMap((item) => item.hits ?? []),
  };
}

export async function assertTextAllowed(text, { field = '内容' } = {}) {
  const result = await reviewText(text, { field });
  if (!result.passed) {
    const error = new Error(result.reason || `${field}包含违规内容，请修改后再提交`);
    error.statusCode = 400;
    error.moderationHits = result.hits;
    throw error;
  }
  return result;
}

export async function assertPayloadAllowed(payload, fields) {
  const result = await reviewPayload(payload, fields);
  if (!result.passed) {
    const error = new Error('内容包含违规信息，请修改后再提交');
    error.statusCode = 400;
    error.moderationHits = result.hits;
    throw error;
  }
  return result;
}
