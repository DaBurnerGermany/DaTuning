const workshop = document.querySelector('#workshop');
const categories = document.querySelector('#categories');
const parts = document.querySelector('#parts');
const status = document.querySelector('#status');
const closeButton = document.querySelector('#close');
const reset = document.querySelector('#reset');
const purchase = document.querySelector('#purchase');
const engineSound = document.querySelector('#engine-sound');
const previewDrag = document.querySelector('#preview-drag');
const panel = workshop.querySelector('.panel');
const summary = document.querySelector('#summary');
const summaryItems = document.querySelector('#summary-items');
let money;
let strings = {};
const dollars = amount => '$' + money.format(amount);
let model = null;
let category = null;
const paintFinishes = ['all', 'standard', 'matte', 'metal'];
const finishFilters = new Map();
let busy = false;
let drag = null;
let pendingTurn = 0;
let sendingTurn = false;

function applyLocale(locale, text) {
    strings = text;
    document.documentElement.lang = locale;
    money = new Intl.NumberFormat(locale === 'en' ? 'en-US' : 'de-DE');
    for (const element of workshop.querySelectorAll('[data-text]')) {
        element.textContent = strings[element.dataset.text];
    }
    for (const element of workshop.querySelectorAll('[data-label]')) {
        element.setAttribute('aria-label', strings[element.dataset.label]);
    }
    for (const element of workshop.querySelectorAll('[data-title]')) {
        element.title = strings[element.dataset.title];
    }
}

function request(action, data = {}) {
    return fetch('https://' + GetParentResourceName() + '/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then(response => response.json());
}

function refreshControls() {
    if (!model) return;
    closeButton.disabled = busy;
    engineSound.disabled = busy;
    purchase.disabled = busy || model.count === 0;
    purchase.title = model.total > 0 ? strings.companyCharge : '';
    reset.disabled = busy || model.count === 0;
    for (const control of parts.querySelectorAll('select, .horn')) control.disabled = busy;
    for (const button of parts.querySelectorAll('.part-reset')) {
        button.disabled = busy || button.dataset.changed !== 'true';
    }
}

function renderSummary(groups) {
    summaryItems.replaceChildren();
    for (const group of groups) {
        for (const item of group.items) {
            if (item.selected === item.current) continue;
            const option = item.options.find(choice => choice.value === item.selected);
            if (!option) continue;

            const row = document.createElement('li');
            const description = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = item.name;
            const selection = document.createElement('span');
            selection.textContent = option.label;
            description.append(name, selection);

            const price = document.createElement('span');
            price.className = 'summary-price';
            price.textContent = dollars(option.price);
            row.append(description, price);
            summaryItems.append(row);
        }
    }
    summary.hidden = summaryItems.childElementCount === 0;
}

function render() {
    const groups = model.groups.filter(group => group.items.length > 0);
    if (!groups.some(group => group.name === category)) category = groups[0]?.name;
    const scroll = parts.scrollTop;
    const focusedId = document.activeElement?.id;
    categories.replaceChildren();
    parts.replaceChildren();

    for (const group of groups) {
        const button = document.createElement('button');
        button.textContent = group.name;
        button.setAttribute('aria-pressed', String(group.name === category));
        button.addEventListener('click', () => {
            category = group.name;
            parts.scrollTop = 0;
            render();
        });
        categories.append(button);
    }

    for (const item of groups.find(group => group.name === category)?.items ?? []) {
        const row = document.createElement('div');
        row.className = 'part';
        row.classList.toggle('changed', item.selected !== item.current);
        const label = document.createElement('label');
        label.className = 'part-label';
        label.htmlFor = 'part-' + item.id;
        label.textContent = item.name;
        const price = document.createElement('span');
        price.className = 'part-price';
        const selected = item.options.find(option => option.value === item.selected);
        price.textContent = item.selected === item.current ? strings.installed : dollars(selected?.price ?? 0);
        if (item.id === 'repair' && item.selected === item.current) price.textContent = '';
        label.append(price);

        const select = document.createElement('select');
        select.id = label.htmlFor;
        const finish = finishFilters.get(item.id) ?? 'all';
        const colorGroups = new Map();
        for (const option of item.options) {
            const outsideFinish = finish !== 'all' && option.finish !== finish;
            if (outsideFinish && option.value !== item.selected) continue;
            const detail = option.value === item.current ? '' : ' · ' + dollars(option.price);
            const choice = new Option(option.label + detail, option.value);
            if (outsideFinish || !option.colorGroup) {
                select.append(choice);
                continue;
            }
            if (!colorGroups.has(option.colorGroupOrder)) {
                const group = document.createElement('optgroup');
                group.label = option.colorGroup;
                colorGroups.set(option.colorGroupOrder, group);
            }
            colorGroups.get(option.colorGroupOrder).append(choice);
        }
        const sortedGroups = [...colorGroups.entries()].sort(([a], [b]) => a - b);
        for (const [, group] of sortedGroups) select.append(group);
        select.value = String(item.selected);
        select.addEventListener('change', () => submit('select', { id: item.id, value: Number(select.value) }));
        const controls = document.createElement('div');
        controls.className = 'part-control';
        if (selected?.swatch) {
            const swatch = document.createElement('span');
            swatch.className = 'swatch';
            swatch.style.backgroundColor = selected.swatch;
            swatch.setAttribute('aria-hidden', 'true');
            controls.append(swatch);
        }
        controls.append(select);
        const resetPart = document.createElement('button');
        resetPart.type = 'button';
        resetPart.className = 'part-reset';
        resetPart.dataset.changed = String(item.selected !== item.current);
        resetPart.title = strings.resetPart.replace('%s', () => item.name);
        resetPart.setAttribute('aria-label', resetPart.title);
        resetPart.textContent = '↶';
        resetPart.addEventListener('click', () => submit('select', { id: item.id, value: item.current }));
        controls.append(resetPart);
        if (item.id === 'modHorns') {
            const horn = document.createElement('button');
            horn.className = 'horn';
            horn.textContent = strings.horn;
            horn.addEventListener('click', () => submit('horn'));
            controls.append(horn);
        }
        row.append(label);
        if (item.id === 'color1' || item.id === 'color2') {
            const filter = document.createElement('select');
            filter.className = 'finish-filter';
            filter.id = 'finish-' + item.id;
            filter.setAttribute('aria-label', strings.filter.replace('%s', () => item.name));
            for (const value of paintFinishes) {
                filter.append(new Option(strings[value], value));
            }
            filter.value = finish;
            filter.addEventListener('change', () => {
                finishFilters.set(item.id, filter.value);
                render();
            });
            row.append(filter);
        }
        row.append(controls);
        parts.append(row);
    }
    parts.scrollTop = scroll;
    renderSummary(groups);
    document.querySelector('#total').textContent = dollars(model.total);
    document.querySelector('#count').textContent = (model.count === 1 ? strings.countOne : strings.countMany).replace('%s', money.format(model.count));
    refreshControls();
    if (focusedId?.startsWith('part-') || focusedId?.startsWith('finish-')) document.getElementById(focusedId)?.focus({ preventScroll: true });
}

async function submit(action, data) {
    if (!model || busy) return;
    busy = true;
    status.textContent = '';
    refreshControls();
    try {
        const response = await request(action, data);
        if (!model) return;
        if (response.ok && response.groups) Object.assign(model, response);
        if (!response.ok) status.textContent = response.message || strings.selectionError;
    } catch {
        if (model) status.textContent = strings.unavailable;
    } finally {
        busy = false;
        if (model && (action === 'select' || action === 'reset')) render();
        else refreshControls();
    }
}

function updatePreviewCenter() {
    if (!model) return;
    const panelEdge = panel.getBoundingClientRect().right;
    const center = (panelEdge + window.innerWidth) / (2 * window.innerWidth);
    request('camera', { center }).catch(() => {});
}

window.addEventListener('resize', updatePreviewCenter);
window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        model = data;
        applyLocale(data.locale, data.text);
        category = null;
        finishFilters.clear();
        summary.open = false;
        busy = false;
        workshop.hidden = false;
        status.textContent = '';
        document.querySelector('#location').textContent = 'DaTuning / ' + data.shop;
        document.querySelector('#vehicle').textContent = data.vehicle;
        document.querySelector('#plate').textContent = data.plate;
        document.querySelector('#storage').textContent = data.registered ? strings.garage : strings.currentOnly;
        render();
        updatePreviewCenter();
    } else if (data.action === 'close') {
        model = null;
        drag = null;
        pendingTurn = 0;
        workshop.hidden = true;
    }
});

closeButton.addEventListener('click', () => submit('close'));
reset.addEventListener('click', () => submit('reset'));
purchase.addEventListener('click', () => submit('purchase'));
engineSound.addEventListener('click', () => submit('engineSound'));
async function sendTurns() {
    if (sendingTurn || !model || pendingTurn === 0) return;
    const turn = Math.max(-360, Math.min(360, pendingTurn));
    pendingTurn -= turn;
    sendingTurn = true;
    try {
        await request('camera', { turn });
    } catch {
        pendingTurn = 0;
    } finally {
        sendingTurn = false;
        if (pendingTurn) requestAnimationFrame(sendTurns);
    }
}

function turnPreview(degrees) {
    if (!model) return;
    pendingTurn += degrees;
    if (!sendingTurn) requestAnimationFrame(sendTurns);
}

previewDrag.addEventListener('pointerdown', event => {
    if (!model || drag || event.button !== 0) return;
    drag = { id: event.pointerId, x: event.clientX };
    previewDrag.setPointerCapture(event.pointerId);
});
previewDrag.addEventListener('pointermove', event => {
    if (drag?.id !== event.pointerId) return;
    turnPreview((event.clientX - drag.x) * 0.45);
    drag.x = event.clientX;
});
previewDrag.addEventListener('lostpointercapture', event => {
    if (drag?.id === event.pointerId) drag = null;
});

document.addEventListener('keydown', event => {
    if (!model) return;
    if (event.key === 'Escape') {
        submit('close');
        return;
    }
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    const key = event.key.toLowerCase();
    if (event.target instanceof HTMLSelectElement && key.startsWith('arrow')) return;
    if (key === 'a' || key === 'arrowleft' || key === 'd' || key === 'arrowright') {
        event.preventDefault();
        turnPreview(key === 'a' || key === 'arrowleft' ? -12 : 12);
    }
});

for (const button of document.querySelectorAll('.camera button[data-turn], .camera button[data-zoom]')) {
    button.addEventListener('click', () => {
        if (button.dataset.turn) turnPreview(Number(button.dataset.turn));
        else request('camera', { zoom: Number(button.dataset.zoom) }).catch(() => {});
    });
}