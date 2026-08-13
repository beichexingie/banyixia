const state = {
  userId: localStorage.getItem('admin_user_id') || '',
  me: null,
  page: 'dashboard',
  rooms: [],
  selectedRoomId: '',
};

const navItems = [
  { id: 'dashboard', label: '数据概览', icon: '▥', permission: 'stats' },
  { id: 'users', label: '用户管理', icon: '♙', permission: 'users' },
  { id: 'orders', label: '订单管理', icon: '🛒', permission: 'orders' },
  { id: 'withdrawals', label: '提现打款', icon: '¥', permission: 'orders' },
  { id: 'insurance', label: '保险审核', icon: '保', permission: 'stats' },
  { id: 'activities', label: '活动管理', icon: '☊', permission: 'activity' },
  { id: 'coupons', label: '优惠券', icon: '券', permission: 'coupon' },
  { id: 'chat', label: '客服工作台', icon: '☎', permission: 'chat' },
  { id: 'tickets', label: '运营工单', icon: '票', permission: 'stats' },
  { id: 'reviews', label: '内容审核', icon: '盾', permission: 'review' },
  { id: 'staff', label: '管理员管理', icon: '管', permission: 'staff' },
  { id: 'logs', label: '操作日志', icon: '志', permission: 'logs' },
  { id: 'system', label: '系统配置', icon: '⚙', permission: 'system' },
];

const els = {
  nav: document.querySelector('#nav'),
  content: document.querySelector('#content'),
  loginPanel: document.querySelector('#loginPanel'),
  adminUserIdInput: document.querySelector('#adminUserIdInput'),
  loginBtn: document.querySelector('#loginBtn'),
  loginError: document.querySelector('#loginError'),
  refreshBtn: document.querySelector('#refreshBtn'),
  switchAccountBtn: document.querySelector('#switchAccountBtn'),
  roleBadge: document.querySelector('#roleBadge'),
  operatorName: document.querySelector('#operatorName'),
  operatorRole: document.querySelector('#operatorRole'),
  globalSearch: document.querySelector('#globalSearch'),
};

function fmtDate(value) {
  if (!value) return '-';
  return new Date(value).toLocaleString('zh-CN', { hour12: false });
}

function money(value) {
  return `¥${Number(value || 0).toLocaleString('zh-CN', { maximumFractionDigits: 2 })}`;
}

function text(value, fallback = '-') {
  return value == null || value === '' ? fallback : String(value);
}

function statusPill(value) {
  const v = text(value, 'unknown');
  const cls = /paid|approved|active|published|3|完成/.test(v)
    ? 'green'
    : /pending|draft|open|transferring|0|1/.test(v)
      ? 'orange'
      : /reject|failed|ban|cancel|offline|4/.test(v)
        ? 'red'
        : '';
  return `<span class="pill ${cls}">${v}</span>`;
}

function parseSnapshot(value) {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_error) {
    return {};
  }
}

function can(permission) {
  return state.me?.permissions?.includes(permission);
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': state.userId,
      ...(options.headers || {}),
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.success === false) {
    throw new Error(data.message || `请求失败: ${response.status}`);
  }
  return data.data ?? data;
}

function toast(message) {
  const node = document.createElement('div');
  node.className = 'toast';
  node.textContent = message;
  document.body.appendChild(node);
  setTimeout(() => node.remove(), 2600);
}

function showLogin() {
  els.loginPanel.classList.add('show');
  els.adminUserIdInput.value = state.userId;
  if (els.loginError) {
    els.loginError.hidden = true;
    els.loginError.textContent = '';
  }
  setTimeout(() => els.adminUserIdInput.focus(), 0);
}

function hideLogin() {
  els.loginPanel.classList.remove('show');
}

function showLoginError(message) {
  if (!els.loginError) return;
  els.loginError.hidden = false;
  els.loginError.textContent = message;
}

function renderNav() {
  const visible = navItems.filter((item) => can(item.permission));
  els.nav.innerHTML = visible
    .map((item) => `
      <button class="${state.page === item.id ? 'active' : ''}" data-page="${item.id}">
        <span class="icon">${item.icon}</span>
        <span>${item.label}</span>
      </button>
    `)
    .join('');
  els.nav.querySelectorAll('button').forEach((button) => {
    button.addEventListener('click', () => {
      state.page = button.dataset.page;
      render();
    });
  });
}

function setShellUser() {
  els.operatorName.textContent = state.me?.display_name || '未登录';
  els.operatorRole.textContent = state.me ? `角色：${state.me.role}` : '请填写后台用户 ID';
  els.roleBadge.textContent = state.me?.role || '访客';
}

function pageHead(title, hint = '') {
  return `
    <h1 class="page-title">${title}</h1>
    ${hint ? `<p class="hint">${hint}</p>` : ''}
  `;
}

function emptyHtml(message = '暂无数据') {
  return `
    <div class="empty">
      <strong>${message}</strong>
      <span>这里展示真实数据库记录，不再使用静态占位数据。</span>
    </div>
  `;
}

function drawLineChart(canvas, rows, field, color) {
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  const w = rect.width;
  const h = rect.height;
  const pad = 38;
  const values = rows.map((row) => Number(row[field] || 0));
  const max = Math.max(1, ...values);
  ctx.clearRect(0, 0, w, h);
  ctx.strokeStyle = '#dfe5ee';
  ctx.lineWidth = 1;
  for (let i = 0; i < 5; i += 1) {
    const y = pad + ((h - pad * 2) * i) / 4;
    ctx.beginPath();
    ctx.moveTo(pad, y);
    ctx.lineTo(w - pad, y);
    ctx.stroke();
  }
  ctx.beginPath();
  values.forEach((value, index) => {
    const x = pad + ((w - pad * 2) * index) / Math.max(1, values.length - 1);
    const y = h - pad - (value / max) * (h - pad * 2);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.lineTo(w - pad, h - pad);
  ctx.lineTo(pad, h - pad);
  ctx.closePath();
  const gradient = ctx.createLinearGradient(0, pad, 0, h - pad);
  gradient.addColorStop(0, `${color}44`);
  gradient.addColorStop(1, `${color}04`);
  ctx.fillStyle = gradient;
  ctx.fill();
  ctx.fillStyle = '#7b8497';
  ctx.font = '12px sans-serif';
  rows.forEach((row, index) => {
    if (index % 3 !== 0 && index !== rows.length - 1) return;
    const x = pad + ((w - pad * 2) * index) / Math.max(1, rows.length - 1);
    ctx.fillText(row.label, Math.min(x, w - pad - 24), h - 10);
  });
}

function drawBarChart(canvas, rows, field) {
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  const w = rect.width;
  const h = rect.height;
  const pad = 38;
  const values = rows.map((row) => Number(row[field] || 0));
  const max = Math.max(1, ...values);
  ctx.clearRect(0, 0, w, h);
  const barW = (w - pad * 2) / Math.max(1, values.length) - 8;
  values.forEach((value, index) => {
    const x = pad + index * (barW + 8);
    const barH = (value / max) * (h - pad * 2);
    const y = h - pad - barH;
    const gradient = ctx.createLinearGradient(0, y, 0, h - pad);
    gradient.addColorStop(0, '#8b5cf6');
    gradient.addColorStop(1, '#5b7cfa');
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.roundRect(x, y, barW, barH, 6);
    ctx.fill();
  });
}

async function renderDashboard() {
  els.content.innerHTML = pageHead('数据概览', '展示来自 RDS 的真实用户、订单、交易和审核数据。') + '<div class="empty">加载中...</div>';
  const data = await api('/api/admin/stats');
  const s = data.summary;
  els.content.innerHTML = `
    ${pageHead('数据概览', '管理员可查看全量统计；客服账号不会显示此页。')}
    <div class="grid stats-grid">
      <div class="card metric"><label>总用户</label><strong>${s.total_users}</strong><span>今日新增 ${s.today_new_users}</span></div>
      <div class="card metric"><label>地陪数</label><strong>${s.total_guides}</strong><span>待审核 ${s.pending_guides}</span></div>
      <div class="card metric"><label>总订单</label><strong>${s.total_orders}</strong><span>今日订单 ${s.today_orders}</span></div>
      <div class="card metric"><label>累计实付</label><strong>${money(s.paid_gmv)}</strong><span>今日 ${money(s.today_gmv)}</span></div>
      <div class="card metric"><label>待审核内容</label><strong>${s.pending_content}</strong><span>帖子/评论/需求</span></div>
      <div class="card metric"><label>客服会话</label><strong>${s.chat_rooms}</strong><span>24h 消息 ${s.messages_24h}</span></div>
    </div>
    <div class="grid two-col" style="margin-top:28px">
      <div class="card"><div class="section-head"><h2>近14天新增用户</h2></div><canvas id="usersChart" class="chart"></canvas></div>
      <div class="card"><div class="section-head"><h2>近14天订单变化</h2></div><canvas id="ordersChart" class="chart"></canvas></div>
      <div class="card"><div class="section-head"><h2>交易额趋势</h2></div><canvas id="gmvChart" class="chart"></canvas></div>
      <div class="card"><div class="section-head"><h2>用户地域分布</h2></div>${renderCityList(data.city)}</div>
    </div>
  `;
  drawLineChart(document.querySelector('#usersChart'), data.daily, 'new_users', '#12c8b2');
  drawLineChart(document.querySelector('#ordersChart'), data.daily, 'orders', '#3f83f8');
  drawBarChart(document.querySelector('#gmvChart'), data.daily, 'gmv');
}

function renderCityList(rows) {
  if (!rows.length) return emptyHtml('暂无城市数据');
  return `
    <table>
      <thead><tr><th>城市</th><th>用户数</th><th>占比</th></tr></thead>
      <tbody>
        ${rows.map((row) => {
          const total = rows.reduce((sum, item) => sum + Number(item.value || 0), 0) || 1;
          return `<tr><td>${row.city}</td><td>${row.value}</td><td>${Math.round((row.value / total) * 100)}%</td></tr>`;
        }).join('')}
      </tbody>
    </table>
  `;
}

async function renderUsers() {
  const q = encodeURIComponent(els.globalSearch.value.trim());
  const rows = await api(`/api/admin/users?q=${q}&limit=80`);
  els.content.innerHTML = `
    ${pageHead('用户管理', '查看用户、地陪身份、封禁状态。封禁操作仅管理员可用。')}
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>用户</th><th>手机号</th><th>城市</th><th>身份</th><th>订单数</th><th>状态</th><th>操作</th></tr></thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td><strong>${text(row.nickname, '未命名')}</strong><br><small>${row.id}</small></td>
                <td>${text(row.phone)}</td>
                <td>${text(row.city)}</td>
                <td>${row.is_admin ? statusPill('admin') : row.is_guide ? statusPill('guide') : statusPill('user')}</td>
                <td>${row.order_count}</td>
                <td>${row.is_banned ? statusPill('banned') : statusPill('normal')}</td>
                <td><button class="soft-btn" data-ban="${row.id}" data-value="${!row.is_banned}">${row.is_banned ? '解封' : '封禁'}</button></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('没有匹配用户')}
    </div>
  `;
  els.content.querySelectorAll('[data-ban]').forEach((button) => {
    button.addEventListener('click', async () => {
      await api(`/api/admin/users/${button.dataset.ban}/ban`, {
        method: 'POST',
        body: JSON.stringify({ is_banned: button.dataset.value === 'true' }),
      });
      toast('用户状态已更新');
      renderUsers();
    });
  });
}

async function renderOrders() {
  const q = encodeURIComponent(els.globalSearch.value.trim());
  const rows = await api(`/api/admin/orders?q=${q}&limit=80`);
  els.content.innerHTML = `
    ${pageHead('订单管理', '查看订单状态、支付状态、用户与地陪。')}
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>订单</th><th>用户</th><th>地陪</th><th>服务</th><th>金额</th><th>状态</th><th>支付</th><th>时间</th></tr></thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td><strong>${row.id}</strong><br><small>${text(row.merchant_order_no)}</small></td>
                <td>${text(row.customer_name)}<br><small>${text(row.customer_phone)}</small></td>
                <td>${text(row.guide_name)}<br><small>${text(row.guide_phone)}</small></td>
                <td><div class="truncate">${text(row.service_name)} / ${text(row.service_city)} ${text(row.service_address)}</div></td>
                <td>${money(row.amount)}</td>
                <td>${statusPill(row.status)}</td>
                <td>${statusPill(row.payment_status)}</td>
                <td>${fmtDate(row.created_at)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('暂无订单')}
    </div>
  `;
}

async function renderReviews() {
  const status = localStorage.getItem('admin_review_status') || 'pending';
  const rows = await api(`/api/admin/review/items?status=${status}`);
  els.content.innerHTML = `
    ${pageHead('内容审核', '审核帖子、评论、需求和地陪入驻申请。')}
    <div class="toolbar">
      <select id="reviewStatus">
        <option value="pending" ${status === 'pending' ? 'selected' : ''}>待审核</option>
        <option value="approved" ${status === 'approved' ? 'selected' : ''}>已通过</option>
        <option value="rejected" ${status === 'rejected' ? 'selected' : ''}>已拒绝</option>
      </select>
    </div>
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>类型</th><th>作者</th><th>内容</th><th>补充</th><th>状态</th><th>时间</th><th>操作</th></tr></thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td>${statusPill(row.type)}</td>
                <td>${text(row.author_name)}<br><small>${row.author_id}</small></td>
                <td><div class="truncate">${text(row.content)}</div></td>
                <td>${text(row.extra)}</td>
                <td>${statusPill(row.review_status)}</td>
                <td>${fmtDate(row.created_at)}</td>
                <td>
                  <button class="primary-btn" data-review="approve" data-type="${row.type}" data-id="${row.id}">通过</button>
                  <button class="danger-btn" data-review="reject" data-type="${row.type}" data-id="${row.id}">拒绝</button>
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('没有待审核内容')}
    </div>
  `;
  document.querySelector('#reviewStatus').addEventListener('change', (event) => {
    localStorage.setItem('admin_review_status', event.target.value);
    renderReviews();
  });
  els.content.querySelectorAll('[data-review]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        button.disabled = true;
        const reason = button.dataset.review === 'reject'
          ? window.prompt('填写拒绝原因，可留空') || ''
          : '';
        await api(`/api/admin/review/${button.dataset.type}/${button.dataset.id}/${button.dataset.review}`, {
          method: 'POST',
          body: JSON.stringify({ reject_reason: reason }),
        });
        toast('审核状态已更新');
        renderReviews();
      } catch (error) {
        toast(`审核失败：${error.message}`);
      } finally {
        button.disabled = false;
      }
    });
  });
}

async function renderChat() {
  state.rooms = await api('/api/admin/chat/rooms');
  if (!state.selectedRoomId && state.rooms[0]) state.selectedRoomId = state.rooms[0].id;
  let detail = null;
  if (state.selectedRoomId) {
    detail = await api(`/api/admin/chat/rooms/${state.selectedRoomId}`);
  }
  els.content.innerHTML = `
    ${pageHead('客服工作台', '客服和运营账号可以查看会话并回复用户。')}
    <div class="chat-layout">
      <div class="card room-list">
        ${state.rooms.length ? state.rooms.map((room) => `
          <button class="room-item ${room.id === state.selectedRoomId ? 'active' : ''}" data-room="${room.id}">
            <strong>${text(room.ticket_title, '在线客服')} · ${room.participants?.map((p) => p.nickname || p.phone || '用户').join(' / ') || '会话'}</strong>
            <p class="truncate">${text(room.last_message, '暂无消息')}</p>
            <small>${room.human_takeover ? '人工处理中' : '自动回复中'} · ${fmtDate(room.last_message_time || room.created_at)}</small>
          </button>
        `).join('') : emptyHtml('暂无客服会话')}
      </div>
      <div class="card">
        <div class="section-head"><h2>会话详情</h2><span class="hint">${state.selectedRoomId || ''}</span></div>
        <div class="message-list">
          ${detail?.messages?.length ? detail.messages.map((msg) => `
            <div class="message ${msg.type === 'support' ? 'support' : ''}">
              <small>${text(msg.sender_name, '用户')} · ${fmtDate(msg.created_at)}</small>
              <div>${text(msg.content)}</div>
            </div>
          `).join('') : emptyHtml('请选择会话或等待用户消息')}
        </div>
        <div class="send-row">
          <input id="replyInput" placeholder="输入客服回复..." />
          <button id="replyBtn" class="primary-btn">发送</button>
        </div>
      </div>
    </div>
  `;
  els.content.querySelectorAll('[data-room]').forEach((button) => {
    button.addEventListener('click', () => {
      state.selectedRoomId = button.dataset.room;
      renderChat();
    });
  });
  document.querySelector('#replyBtn')?.addEventListener('click', async () => {
    const input = document.querySelector('#replyInput');
    if (!state.selectedRoomId || !input.value.trim()) return;
    await api(`/api/admin/chat/rooms/${state.selectedRoomId}/messages`, {
      method: 'POST',
      body: JSON.stringify({ content: input.value.trim() }),
    });
    input.value = '';
    toast('已发送');
    renderChat();
  });
}

async function renderActivities() {
  const rows = await api('/api/admin/activities');
  els.content.innerHTML = `
    ${pageHead('活动管理', '创建活动草稿或直接发布，供后续客户端活动位调用。')}
    <div class="card">
      <div class="form-grid">
        <input id="activityTitle" placeholder="活动标题" />
        <select id="activityStatus"><option value="draft">草稿</option><option value="published">发布</option><option value="offline">下线</option></select>
        <input id="activitySummary" class="wide" placeholder="活动摘要" />
        <textarea id="activityContent" rows="4" placeholder="活动内容"></textarea>
      </div>
      <button id="createActivityBtn" class="primary-btn">创建活动</button>
    </div>
    <div class="card table-wrap" style="margin-top:18px">
      ${rows.length ? `
        <table>
          <thead><tr><th>标题</th><th>摘要</th><th>状态</th><th>创建时间</th></tr></thead>
          <tbody>${rows.map((row) => `<tr><td>${text(row.title)}</td><td>${text(row.summary)}</td><td>${statusPill(row.status)}</td><td>${fmtDate(row.created_at)}</td></tr>`).join('')}</tbody>
        </table>
      ` : emptyHtml('暂无活动')}
    </div>
  `;
  document.querySelector('#createActivityBtn').addEventListener('click', async () => {
    await api('/api/admin/activities', {
      method: 'POST',
      body: JSON.stringify({
        title: document.querySelector('#activityTitle').value,
        summary: document.querySelector('#activitySummary').value,
        content: document.querySelector('#activityContent').value,
        status: document.querySelector('#activityStatus').value,
      }),
    });
    toast('活动已创建');
    renderActivities();
  });
}

async function renderCoupons() {
  const rows = await api('/api/admin/coupons');
  els.content.innerHTML = `
    ${pageHead('优惠券', '创建优惠券批次，后面可以继续接定向发放和用户领取。')}
    <div class="card">
      <div class="form-grid">
        <input id="couponTitle" placeholder="优惠券名称" />
        <input id="couponCode" placeholder="优惠码，可留空" />
        <input id="couponAmount" type="number" step="0.01" placeholder="抵扣金额" />
        <input id="couponMinSpend" type="number" step="0.01" placeholder="最低消费" />
        <input id="couponTotal" type="number" placeholder="发行数量" />
        <select id="couponStatus"><option value="draft">草稿</option><option value="active">启用</option><option value="offline">下线</option></select>
      </div>
      <button id="createCouponBtn" class="primary-btn">创建优惠券</button>
    </div>
    <div class="card table-wrap" style="margin-top:18px">
      ${rows.length ? `
        <table>
          <thead><tr><th>名称</th><th>优惠码</th><th>金额</th><th>门槛</th><th>数量</th><th>状态</th><th>创建时间</th></tr></thead>
          <tbody>${rows.map((row) => `<tr><td>${text(row.title)}</td><td>${text(row.code)}</td><td>${money(row.amount)}</td><td>${money(row.min_spend)}</td><td>${row.issued_count}/${row.total_count}</td><td>${statusPill(row.status)}</td><td>${fmtDate(row.created_at)}</td></tr>`).join('')}</tbody>
        </table>
      ` : emptyHtml('暂无优惠券')}
    </div>
  `;
  document.querySelector('#createCouponBtn').addEventListener('click', async () => {
    await api('/api/admin/coupons', {
      method: 'POST',
      body: JSON.stringify({
        title: document.querySelector('#couponTitle').value,
        code: document.querySelector('#couponCode').value,
        amount: document.querySelector('#couponAmount').value,
        min_spend: document.querySelector('#couponMinSpend').value,
        total_count: document.querySelector('#couponTotal').value,
        status: document.querySelector('#couponStatus').value,
      }),
    });
    toast('优惠券已创建');
    renderCoupons();
  });
}

async function renderStaff() {
  const rows = await api('/api/admin/staff');
  els.content.innerHTML = `
    ${pageHead('管理员管理', '给已有用户授予 support/operator/reviewer 后台权限。')}
    <div class="card">
      <div class="form-grid">
        <input id="staffUserId" class="wide" placeholder="用户 user_id" />
        <input id="staffName" placeholder="后台显示名" />
        <select id="staffRole"><option value="support">客服</option><option value="operator">运营</option><option value="reviewer">审核员</option><option value="admin">管理员</option></select>
      </div>
      <button id="saveStaffBtn" class="primary-btn">保存角色</button>
    </div>
    <div class="card table-wrap" style="margin-top:18px">
      ${rows.length ? `
        <table>
          <thead><tr><th>用户</th><th>手机号</th><th>角色</th><th>权限</th><th>状态</th><th>创建时间</th></tr></thead>
          <tbody>${rows.map((row) => `<tr><td>${text(row.display_name || row.nickname)}<br><small>${row.user_id}</small></td><td>${text(row.phone)}</td><td>${statusPill(row.role)}</td><td>${(row.permissions || []).join(', ') || '默认权限'}</td><td>${statusPill(row.is_active ? 'active' : 'disabled')}</td><td>${fmtDate(row.created_at)}</td></tr>`).join('')}</tbody>
        </table>
      ` : emptyHtml('暂无客服/运营账号')}
    </div>
  `;
  document.querySelector('#saveStaffBtn').addEventListener('click', async () => {
    await api('/api/admin/staff', {
      method: 'POST',
      body: JSON.stringify({
        user_id: document.querySelector('#staffUserId').value,
        display_name: document.querySelector('#staffName').value,
        role: document.querySelector('#staffRole').value,
      }),
    });
    toast('后台角色已保存');
    renderStaff();
  });
}

async function renderWithdrawals() {
  const status = localStorage.getItem('admin_withdrawal_status') || '';
  const [rows, payoutAccounts] = await Promise.all([
    api(`/api/admin/withdrawals${status ? `?status=${status}` : ''}`),
    api('/api/admin/payout-accounts?status=pending'),
  ]);
  els.content.innerHTML = `
    ${pageHead('提现打款', '地陪提现先审核，再调用支付宝商家转账；失败的单可以重试或手动兜底。')}
    <div class="card table-wrap" style="margin-bottom:18px">
      <div class="section-head"><h2>待审核收款账号</h2><span class="hint">${payoutAccounts.length} 条</span></div>
      ${payoutAccounts.length ? `
        <table>
          <thead><tr><th>地陪</th><th>实名</th><th>支付宝账号</th><th>User ID</th><th>更新时间</th><th>操作</th></tr></thead>
          <tbody>
            ${payoutAccounts.map((row) => `
              <tr>
                <td>${text(row.nickname, '未命名')}<br><small>${text(row.phone)}</small></td>
                <td>${text(row.real_name)}</td>
                <td>${text(row.alipay_account)}</td>
                <td>${text(row.alipay_user_id)}</td>
                <td>${fmtDate(row.updated_at)}</td>
                <td class="action-cell">
                  <button class="primary-btn" data-payout-action="approve" data-user-id="${row.user_id}">通过</button>
                  <button class="danger-btn" data-payout-action="reject" data-user-id="${row.user_id}">驳回</button>
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('暂无待审核收款账号')}
    </div>
    <div class="toolbar">
      <select id="withdrawalStatus">
        <option value="" ${status === '' ? 'selected' : ''}>全部状态</option>
        <option value="pending" ${status === 'pending' ? 'selected' : ''}>待审核</option>
        <option value="approved" ${status === 'approved' ? 'selected' : ''}>待打款</option>
        <option value="transferring" ${status === 'transferring' ? 'selected' : ''}>打款中</option>
        <option value="transfer_failed" ${status === 'transfer_failed' ? 'selected' : ''}>打款失败</option>
        <option value="paid" ${status === 'paid' ? 'selected' : ''}>已打款</option>
        <option value="rejected" ${status === 'rejected' ? 'selected' : ''}>已驳回</option>
      </select>
    </div>
    <div class="card table-wrap">
      ${rows.length ? `
        <table class="wide-table">
          <thead><tr><th>地陪</th><th>金额</th><th>收款账号</th><th>状态</th><th>流水/原因</th><th>时间</th><th>操作</th></tr></thead>
          <tbody>
            ${rows.map((row) => {
              const account = parseSnapshot(row.payout_account_snapshot);
              const canApprove = row.status === 'pending';
              const canTransfer = row.status === 'approved' || row.status === 'transfer_failed';
              const canReject = row.status === 'pending' || row.status === 'approved' || row.status === 'transfer_failed';
              const canQuery = row.status === 'transferring' || row.status === 'transfer_failed';
              return `
                <tr>
                  <td><strong>${text(row.nickname, '未命名')}</strong><br><small>${text(row.phone)}</small><br><small>${row.user_id}</small></td>
                  <td><strong>${money(row.amount)}</strong></td>
                  <td>
                    <div>${text(account.real_name, '未填实名')}</div>
                    <small>账号：${text(account.alipay_account)}</small><br>
                    <small>User ID：${text(account.alipay_user_id)}</small>
                  </td>
                  <td>${statusPill(row.status)}</td>
                  <td>
                    <div class="truncate">${text(row.provider_order_no, '暂无支付宝流水')}</div>
                    ${row.reject_reason ? `<small class="danger-text">${text(row.reject_reason)}</small>` : ''}
                  </td>
                  <td><small>申请：${fmtDate(row.created_at)}</small><br><small>审核：${fmtDate(row.reviewed_at)}</small><br><small>打款：${fmtDate(row.paid_at)}</small></td>
                  <td class="action-cell">
                    ${canApprove ? `<button class="primary-btn" data-withdrawal-action="approve" data-id="${row.id}">审核通过</button>` : ''}
                    ${canTransfer ? `<button class="primary-btn" data-withdrawal-action="transfer" data-id="${row.id}">自动打款</button>` : ''}
                    ${canQuery ? `<button class="soft-btn" data-withdrawal-action="query" data-id="${row.id}">查询状态</button>` : ''}
                    ${canReject ? `<button class="danger-btn" data-withdrawal-action="reject" data-id="${row.id}">驳回</button>` : ''}
                    ${canTransfer ? `<button class="soft-btn" data-withdrawal-action="mark-paid" data-id="${row.id}">手动标记</button>` : ''}
                  </td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      ` : emptyHtml('暂无提现申请')}
    </div>
  `;

  document.querySelector('#withdrawalStatus').addEventListener('change', (event) => {
    localStorage.setItem('admin_withdrawal_status', event.target.value);
    renderWithdrawals();
  });

  els.content.querySelectorAll('[data-payout-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const { payoutAction: action, userId } = button.dataset;
      try {
        button.disabled = true;
        if (action === 'approve') {
          await api(`/api/admin/payout-accounts/${userId}/approve`, { method: 'POST' });
          toast('收款账号已通过');
        } else {
          const reason = window.prompt('填写驳回原因，可留空') || '';
          await api(`/api/admin/payout-accounts/${userId}/reject`, {
            method: 'POST',
            body: JSON.stringify({ reason }),
          });
          toast('收款账号已驳回');
        }
        renderWithdrawals();
      } catch (error) {
        toast(`收款账号操作失败：${error.message}`);
      } finally {
        button.disabled = false;
      }
    });
  });

  els.content.querySelectorAll('[data-withdrawal-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const { withdrawalAction: action, id } = button.dataset;
      try {
        button.disabled = true;
        if (action === 'approve') {
          await api(`/api/admin/withdrawals/${id}/approve`, { method: 'POST' });
          toast('提现已审核通过');
        } else if (action === 'transfer') {
          const confirmed = window.confirm('确认调用支付宝商家转账？成功后会真实打款到地陪支付宝。');
          if (!confirmed) return;
          await api(`/api/admin/withdrawals/${id}/transfer`, {
            method: 'POST',
            body: JSON.stringify({ remark: '一点伴地陪提现' }),
          });
          toast('支付宝自动打款成功');
        } else if (action === 'reject') {
          const reason = window.prompt('填写驳回原因，可留空') || '';
          await api(`/api/admin/withdrawals/${id}/reject`, {
            method: 'POST',
            body: JSON.stringify({ reason }),
          });
          toast('提现已驳回，余额已退回');
        } else if (action === 'query') {
          await api(`/api/admin/withdrawals/${id}/query-transfer`, { method: 'POST' });
          toast('支付宝转账状态已更新');
        } else if (action === 'mark-paid') {
          const providerOrderNo = window.prompt('填写线下/支付宝流水号，可留空') || '';
          await api(`/api/admin/withdrawals/${id}/mark-paid`, {
            method: 'POST',
            body: JSON.stringify({ provider_order_no: providerOrderNo }),
          });
          toast('已手动标记为打款完成');
        }
        renderWithdrawals();
      } catch (error) {
        toast(`操作失败：${error.message}`);
      } finally {
        button.disabled = false;
      }
    });
  });
}

async function renderInsurance() {
  const rows = await api('/api/admin/guide-insurance');
  els.content.innerHTML = `
    ${pageHead('地陪保险审核', '审核地陪提交的保险资料。通过后，地陪端会显示已保障状态。')}
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>地陪</th><th>保险公司</th><th>保单号</th><th>到期日</th><th>状态</th><th>原因</th><th>操作</th></tr></thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td><strong>${text(row.nickname, '未命名')}</strong><br><small>${text(row.phone)}</small></td>
                <td>${text(row.provider)}</td>
                <td>${text(row.policy_no)}</td>
                <td>${text(row.expires_at)}</td>
                <td>${statusPill(row.status)}</td>
                <td>${text(row.reject_reason)}</td>
                <td class="action-cell">
                  ${row.status === 'pending' ? `<button class="primary-btn" data-insurance-action="approve" data-guide-id="${row.guide_id}">通过</button><button class="danger-btn" data-insurance-action="reject" data-guide-id="${row.guide_id}">驳回</button>` : '-'}
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('暂无保险资料')}
    </div>
  `;
  els.content.querySelectorAll('[data-insurance-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const { insuranceAction: action, guideId } = button.dataset;
      try {
        button.disabled = true;
        const body = action === 'reject'
          ? { reason: window.prompt('填写驳回原因，可留空') || '' }
          : {};
        await api(`/api/admin/guide-insurance/${guideId}/${action}`, {
          method: 'POST',
          body: JSON.stringify(body),
        });
        toast(action === 'approve' ? '保险资料已通过' : '保险资料已驳回');
        renderInsurance();
      } catch (error) {
        toast(`操作失败：${error.message}`);
      } finally {
        button.disabled = false;
      }
    });
  });
}

async function renderLogs() {
  const rows = await api('/api/admin/logs');
  els.content.innerHTML = `
    ${pageHead('操作日志', '记录后台关键操作，便于追溯审核和客服行为。')}
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>操作人</th><th>动作</th><th>对象</th><th>详情</th><th>时间</th></tr></thead>
          <tbody>${rows.map((row) => `<tr><td>${text(row.actor_name)}<br><small>${text(row.actor_user_id)}</small></td><td>${row.action}</td><td>${text(row.target_type)}<br><small>${text(row.target_id)}</small></td><td><div class="truncate">${JSON.stringify(row.detail || {})}</div></td><td>${fmtDate(row.created_at)}</td></tr>`).join('')}</tbody>
        </table>
      ` : emptyHtml('暂无操作日志')}
    </div>
  `;
}

async function renderTickets() {
  const rows = await api('/api/admin/guide-support-requests');
  els.content.innerHTML = `
    ${pageHead('运营工单', '展示地陪端提交的运营咨询、订单协助、活动报名和申诉。')}
    <div class="card table-wrap">
      ${rows.length ? `
        <table>
          <thead><tr><th>地陪</th><th>类型</th><th>问题</th><th>运营回复</th><th>状态</th><th>时间</th><th>操作</th></tr></thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td><strong>${text(row.nickname, '未命名')}</strong><br><small>${text(row.phone)}</small></td>
                <td>${text(row.category)}</td>
                <td><div class="truncate">${text(row.content)}</div></td>
                <td><div class="truncate">${text(row.reply)}</div></td>
                <td>${statusPill(row.status)}</td>
                <td>${fmtDate(row.created_at)}</td>
                <td>${row.status === 'open' ? `<button class="primary-btn" data-guide-ticket="${row.id}">回复</button>` : '-'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : emptyHtml('暂无地陪运营工单')}
    </div>
  `;
  els.content.querySelectorAll('[data-guide-ticket]').forEach((button) => {
    button.addEventListener('click', async () => {
      const reply = window.prompt('填写给地陪的运营回复') || '';
      if (!reply) return;
      try {
        button.disabled = true;
        await api(`/api/admin/guide-support-requests/${button.dataset.guideTicket}/reply`, {
          method: 'POST',
          body: JSON.stringify({ reply }),
        });
        toast('运营回复已发送');
        renderTickets();
      } catch (error) {
        toast(`回复失败：${error.message}`);
      } finally {
        button.disabled = false;
      }
    });
  });
}

function renderSystem() {
  els.content.innerHTML = `
    ${pageHead('系统配置', '这里先展示当前后台配置建议，正式上线前再接可编辑配置项。')}
    <div class="grid two-col">
      <div class="card">
        <h2>角色边界</h2>
        <p><strong>admin</strong>：统计、用户、订单、审核、客服、活动、优惠券、员工、日志、系统配置。</p>
        <p><strong>support/operator/reviewer</strong>：客服、审核、活动、优惠券等运营入口，不看全量财务统计。</p>
      </div>
      <div class="card">
        <h2>上线前建议</h2>
        <p>后台建议只走 HTTPS，并加独立后台登录密码/JWT；Nginx 可限制 `/admin/` 访问来源或加 Basic Auth。</p>
      </div>
    </div>
  `;
}

async function render() {
  renderNav();
  setShellUser();
  try {
    if (state.page === 'dashboard') return renderDashboard();
    if (state.page === 'users') return renderUsers();
    if (state.page === 'orders') return renderOrders();
    if (state.page === 'withdrawals') return renderWithdrawals();
    if (state.page === 'insurance') return renderInsurance();
    if (state.page === 'reviews') return renderReviews();
    if (state.page === 'chat') return renderChat();
    if (state.page === 'tickets') return renderTickets();
    if (state.page === 'activities') return renderActivities();
    if (state.page === 'coupons') return renderCoupons();
    if (state.page === 'staff') return renderStaff();
    if (state.page === 'logs') return renderLogs();
    if (state.page === 'system') return renderSystem();
  } catch (error) {
    els.content.innerHTML = `${pageHead('加载失败')}<div class="empty"><strong>${error.message}</strong><span>请检查后台用户权限、SQL 补丁是否已导入、服务是否已重启。</span></div>`;
  }
}

async function boot() {
  if (!state.userId) {
    showLogin();
    return;
  }
  try {
    state.me = await api('/api/admin/me');
    const firstAllowed = navItems.find((item) => can(item.permission));
    state.page = can(navItems.find((item) => item.id === state.page)?.permission)
      ? state.page
      : firstAllowed?.id || 'chat';
    hideLogin();
    render();
  } catch (error) {
    showLogin();
    els.operatorRole.textContent = error.message;
    showLoginError(error.message || '后台账号验证失败');
  }
}

els.loginBtn.addEventListener('click', async () => {
  state.userId = els.adminUserIdInput.value.trim();
  if (!state.userId) {
    showLoginError('请先填写管理员或客服用户 ID。');
    return;
  }
  localStorage.setItem('admin_user_id', state.userId);
  els.loginBtn.disabled = true;
  els.loginBtn.textContent = '正在验证...';
  try {
    await boot();
  } finally {
    els.loginBtn.disabled = false;
    els.loginBtn.textContent = '进入后台';
  }
});

els.switchAccountBtn.addEventListener('click', () => {
  showLogin();
});

els.refreshBtn.addEventListener('click', () => {
  render();
});

els.globalSearch.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') render();
});

boot();
