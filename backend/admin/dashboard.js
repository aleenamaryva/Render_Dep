const state = { token: sessionStorage.getItem('lifetrace_admin_token'), page: 1, pageSize: 20, total: 0 };
const $ = (id) => document.getElementById(id);

function showDashboard() { $('login-view').hidden = true; $('dashboard-view').hidden = false; loadDashboard(); }
function showLogin() { $('login-view').hidden = false; $('dashboard-view').hidden = true; }
function setError(message) { $('dashboard-error').textContent = message || ''; }
async function api(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  const response = await fetch(path, { ...options, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.detail || body.message || 'Request failed.');
  return body;
}
function renderSummary(data) {
  $('summary').innerHTML = [['total_citizens','Registered citizens'],['safe_responses','Safe responses'],['help_requests','Help requests'],['pending_responses','Pending responses']].map(([key,label]) => `<div class="metric"><strong>${data[key]}</strong><span>${label}</span></div>`).join('');
}
function formatDate(value) { return value ? new Date(value).toLocaleString() : 'Unavailable'; }
function locationText(item) { return item.latitude == null || item.longitude == null ? 'Location unavailable' : `${Number(item.latitude).toFixed(6)}, ${Number(item.longitude).toFixed(6)}`; }
function renderRows(items) {
  $('response-rows').innerHTML = items.map(item => `<tr><td class="${item.response_type === 'NEED_HELP' ? 'urgent' : 'safe'}">${item.response_type === 'NEED_HELP' ? 'URGENT' : 'SAFE'}</td><td><strong>${escapeHtml(item.citizen_name)}</strong><br><small>${escapeHtml(item.citizen_phone)}</small>${item.is_mesh_relayed ? `<br><span class="mesh-badge">📡 Mesh (${item.hop_count} hops)</span>` : ''}</td><td>${item.response_type}</td><td>${locationText(item)}</td><td>${formatDate(item.submitted_at)}</td><td><span class="status status-${item.rescue_status}">${item.rescue_status}</span></td><td><button class="secondary" data-details="${item.id}">Details</button><select data-status="${item.id}" aria-label="Update rescue status"><option value="">Update</option><option>PENDING</option><option>ASSIGNED</option><option>RESOLVED</option></select></td></tr>`).join('') || '<tr><td colspan="7">No responses match these filters.</td></tr>';
  document.querySelectorAll('[data-details]').forEach(button => button.addEventListener('click', () => showDetails(button.dataset.details)));
  document.querySelectorAll('[data-status]').forEach(select => select.addEventListener('change', () => updateStatus(select.dataset.status, select.value)));
}
function escapeHtml(value) { return String(value ?? '').replace(/[&<>'"]/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[character])); }
async function loadResponses() {
  const params = new URLSearchParams({ page: state.page, page_size: state.pageSize });
  if ($('type-filter').value) params.set('response_type', $('type-filter').value);
  if ($('status-filter').value) params.set('rescue_status', $('status-filter').value);
  if ($('date-filter').value) params.set('submitted_on', $('date-filter').value);
  const data = await api(`/admin/responses?${params}`); state.total = data.total; renderRows(data.items); $('page-label').textContent = `Page ${data.page} of ${Math.max(1, Math.ceil(data.total / data.page_size))}`; $('previous-page').disabled = state.page <= 1; $('next-page').disabled = state.page * state.pageSize >= data.total;
}
async function loadDashboard() { try { setError(''); renderSummary(await api('/admin/summary')); await loadResponses(); } catch (error) { setError(error.message); if (error.message.includes('Administrator') || error.message.includes('Authentication')) { sessionStorage.removeItem('lifetrace_admin_token'); state.token = null; showLogin(); } } }
async function showDetails(id) { try { const item = await api(`/admin/responses/${id}`); $('details-content').innerHTML = `<div class="detail-grid"><div><small>Citizen</small>${escapeHtml(item.citizen_name)}</div><div><small>Email</small>${escapeHtml(item.citizen_email)}</div><div><small>Phone</small>${escapeHtml(item.citizen_phone)}</div><div><small>Emergency contact</small>${escapeHtml(item.emergency_contact_name)} (${escapeHtml(item.emergency_contact_phone)})</div><div><small>Response</small>${item.response_type}</div><div><small>Status</small>${item.rescue_status}</div><div><small>Transmission</small>${item.is_mesh_relayed ? `<span class="mesh-badge">📡 Mesh Relayed (${item.hop_count} hops)</span>` : 'Direct Internet'}</div><div><small>Location</small>${locationText(item)}</div><div><small>Submitted</small>${formatDate(item.submitted_at)}</div></div>`; $('details-dialog').showModal(); } catch (error) { setError(error.message); } }
async function updateStatus(id, status) { if (!status) return; try { await api(`/admin/responses/${id}`, { method: 'PATCH', body: JSON.stringify({ rescue_status: status }) }); await loadDashboard(); } catch (error) { setError(error.message); } }
$('login-form').addEventListener('submit', async event => { event.preventDefault(); $('login-error').textContent = ''; try { const data = await api('/login', { method: 'POST', body: JSON.stringify({ email: $('email').value, password: $('password').value }) }); if (data.user.role !== 'admin') throw new Error('Administrator access required.'); state.token = data.access_token; sessionStorage.setItem('lifetrace_admin_token', state.token); showDashboard(); } catch (error) { $('login-error').textContent = error.message; } });
$('filters').addEventListener('submit', event => { event.preventDefault(); state.page = 1; loadResponses().catch(error => setError(error.message)); });
$('refresh-button').addEventListener('click', () => loadDashboard()); $('previous-page').addEventListener('click', () => { if (state.page > 1) { state.page--; loadResponses(); } }); $('next-page').addEventListener('click', () => { if (state.page * state.pageSize < state.total) { state.page++; loadResponses(); } }); $('logout-button').addEventListener('click', () => { sessionStorage.removeItem('lifetrace_admin_token'); state.token = null; showLogin(); }); $('close-dialog').addEventListener('click', () => $('details-dialog').close());
if (state.token) showDashboard(); else showLogin();
