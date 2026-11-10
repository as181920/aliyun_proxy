(() => {
  if (window.aliyunLoginCaptchaInstalled) return;
  window.aliyunLoginCaptchaInstalled = true;
  const approved = new WeakSet();
  let pending;

  const cleanup = () => {
    if (!pending) return;
    pending.request.abort();
    pending.frame.src = 'about:blank';
    pending.frame.hidden = true;
    pending.dialog.close();
    pending = null;
  };

  document.addEventListener('submit', async (event) => {
    const form = event.target;
    const dialog = document.querySelector('[data-login-captcha]');
    if (!dialog || !['session-form-by-password', 'session-form-by-verification-code'].includes(form.id)) return;
    if (approved.delete(form)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (pending) return;

    const frame = dialog.querySelector('iframe');
    const status = dialog.querySelector('[role="status"]');
    const request = new AbortController();
    const attempt = { form, dialog, frame, request, submitter: event.submitter };
    pending = attempt;
    dialog.querySelector('button').onclick = cleanup;
    dialog.oncancel = cleanup;
    dialog.showModal();
    const body = new FormData(form);
    if (dialog.dataset.locale) body.set('locale', dialog.dataset.locale);
    // Human verification never needs the password or an earlier proof.
    body.delete('session[password]');
    body.delete('session[verification_code]');
    body.delete('captcha_challenge');
    try {
      const response = await fetch(form.action, {
        method: 'POST', credentials: 'same-origin', body, signal: request.signal,
        headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || body.get('authenticity_token') || '' }
      });
      const result = await response.json();
      if (pending !== attempt) return;
      if (result.error?.code !== 'captcha.required' || !result.challenge_id) {
        status.textContent = result.error?.message || dialog.dataset.error;
        return;
      }
      const target = new URL(result.challenge_url, window.location.href);
      if (target.origin !== window.location.origin) throw new Error(dialog.dataset.error);
      attempt.challenge = result.challenge_id;
      frame.src = target.href;
      frame.hidden = false;
      status.textContent = '';
    } catch (_) {
      if (pending === attempt) status.textContent = dialog.dataset.error;
    }
  }, true);

  window.addEventListener('message', (event) => {
    const attempt = pending;
    if (!attempt || event.origin !== window.location.origin || event.source !== attempt.frame.contentWindow) return;
    if (event.data?.challenge !== attempt.challenge) return;
    if (event.data.type === 'aliyun_proxy:captcha_cancelled') { cleanup(); return; }
    if (event.data.type !== 'aliyun_proxy:captcha_verified') return;
    const fields = { captcha_challenge: attempt.challenge };
    if (attempt.dialog.dataset.locale) fields.locale = attempt.dialog.dataset.locale;
    Object.entries(fields).forEach(([name, value]) => {
      let input = attempt.form.querySelector(`[name="${name}"]`);
      if (!input) {
        input = document.createElement('input');
        input.type = 'hidden';
        input.name = name;
        attempt.form.appendChild(input);
      }
      input.value = value;
    });
    approved.add(attempt.form);
    cleanup();
    if (attempt.submitter) attempt.form.requestSubmit(attempt.submitter);
    else attempt.form.requestSubmit();
  });

  document.addEventListener('turbo:before-cache', () => {
    cleanup();
    document.querySelectorAll('[name="session[password]"], [name="session[verification_code]"]').forEach((input) => { input.value = ''; });
  });
  document.addEventListener('turbo:before-render', cleanup);
})();
