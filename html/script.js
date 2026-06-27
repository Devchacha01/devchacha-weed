const RESOURCE_NAME = "devchacha-weed";

// Menu State
let currentMenuOptions = [];
let selectedIndex = 0;
let isMenuOpen = false;

// Quantity Modal State
let selectedItem = null;
let selectedPrice = 0;

// Plant State
let currentPlantId = null;

// Helper functions (replacing jQuery)
function $(selector) {
    return document.querySelector(selector);
}

function show(el) {
    if (typeof el === 'string') el = document.querySelector(el);
    if (el) el.classList.remove('hidden');
}

function hide(el) {
    if (typeof el === 'string') el = document.querySelector(el);
    if (el) el.classList.add('hidden');
}

function isHidden(el) {
    if (typeof el === 'string') el = document.querySelector(el);
    return el ? el.classList.contains('hidden') : true;
}

function post(url, data) {
    fetch('https://' + RESOURCE_NAME + '/' + url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(function(resp) {
        return resp.text();
    }).then(function(text) {
        let result = null;
        try {
            result = JSON.parse(text);
        } catch (e) {
            result = text;
        }
        
        // Handle callback results for plant actions
        if (url === 'plantAction' && result && typeof result === 'object') {
            if (result.success) {
                if (result.newPlantData) updatePlantUI(result.newPlantData);
                if (result.message) showToast(result.message);
            } else {
                if (result.message) showToast(result.message);
            }
        }
    }).catch(function(err) {
        console.error('NUI Post Error:', err);
    });
}

console.log("[devchacha-weed] NUI Script Loaded!");

window.addEventListener('message', function (event) {
    let data = event.data;
    console.log("[devchacha-weed] NUI Event received: " + data.action);

    if (data.action === "openMenu") {
        openMenu(data.title, data.options, data.description);
    } else if (data.action === "closeMenu") {
        closeMenu();
    } else if (data.action === "openQuantityModal") {
        openQuantityModal(data.item, data.label, data.price);
    } else if (data.action === 'openPlant') {
        currentPlantId = data.plant.id;
        show('#plant-menu');
        updatePlantUI(data.plant);
    } else if (data.action === 'openSelling') {
        $('#sell-offer-text').innerHTML = 'I\'ll give you <span class="highlight-price">$' + data.price + '</span> for <span class="highlight-item">' + data.amount + 'x ' + data.label + '</span>.';
        show('#selling-interaction');
    } else if (data.action === 'close') {
        closePlantMenu();
        hide('#selling-interaction');
    }
});

// Keyboard Navigation
document.addEventListener('keydown', function (event) {
    if (isMenuOpen) {
        if (event.which == 37) { // Left
            selectedIndex--;
            if (selectedIndex < 0) selectedIndex = currentMenuOptions.length - 1;
            updateSelection();
        } else if (event.which == 39) { // Right
            selectedIndex++;
            if (selectedIndex >= currentMenuOptions.length) selectedIndex = 0;
            updateSelection();
        } else if (event.which == 38) { // Up
            selectedIndex -= 4;
            if (selectedIndex < 0) selectedIndex = 0;
            updateSelection();
        } else if (event.which == 40) { // Down
            selectedIndex += 4;
            if (selectedIndex >= currentMenuOptions.length) selectedIndex = currentMenuOptions.length - 1;
            updateSelection();
        } else if (event.which == 13) { // Enter
            selectOption();
        } else if (event.which == 8) { // Backspace
            closeMenu();
            post('closeMenu');
        }
    }

    if (event.key === 'Escape' || event.which == 8) { // ESC or Backspace
        if (!isHidden('#quantity-modal')) {
            closeQuantityModal();
        } else if (isMenuOpen) {
            closeMenu();
            post('closeMenu');
        } else if (!isHidden('#plant-menu')) {
            closePlantMenu();
        }
    }
});

/* Shop Menu Functions */
function openMenu(title, options, description) {
    $("#menu-title").textContent = title;

    if (description) {
        $("#menu-description").textContent = description;
        show("#menu-description");
    } else {
        hide("#menu-description");
    }

    var optionsList = $("#menu-options-list");
    optionsList.innerHTML = '';
    currentMenuOptions = options;
    selectedIndex = 0;

    options.forEach(function(opt, index) {
        let imgHtml = '';
        if (opt.image) {
            imgHtml = '<div class="image-wrapper"><img src="' + opt.image + '" onerror="this.style.display=\'none\'"></div>';
        } else {
            imgHtml = '<div class="image-wrapper"><span style="font-size:48px;color:#5d4037;">📦</span></div>';
        }

        let priceHtml = '';
        if (opt.price) {
            priceHtml = '<div class="price-badge">$' + opt.price + '</div>';
        }

        let btnText = opt.btnLabel || "BUY";

        let el = document.createElement('div');
        el.className = 'menu-option';
        el.id = 'opt-' + index;
        el.innerHTML = priceHtml + imgHtml + '<div class="title">' + opt.title + '</div><div class="buy-btn">' + btnText + '</div>';

        el.addEventListener('click', function () {
            selectedIndex = index;
            updateSelection();
            selectOption();
        });

        optionsList.appendChild(el);
    });

    updateSelection();
    show("#menu-interface");
    isMenuOpen = true;
}

function updateSelection() {
    document.querySelectorAll(".menu-option").forEach(function(el) {
        el.classList.remove("selected");
    });
    var el = document.getElementById('opt-' + selectedIndex);
    if (el) {
        el.classList.add("selected");
        el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
}

function selectOption() {
    let opt = currentMenuOptions[selectedIndex];
    console.log("[devchacha-weed] selectOption called inside JS with index: " + selectedIndex + " for item: " + (opt ? opt.title : "none"));
    if (opt) {
        post('selectOption', {
            index: selectedIndex + 1,
            data: opt
        });
    }
}

function closeMenu() {
    hide("#menu-interface");
    isMenuOpen = false;
}

/* Quantity Modal Functions */
function openQuantityModal(itemName, itemLabel, price) {
    selectedItem = { name: itemName, label: itemLabel };
    selectedPrice = price;

    $('#quantity-title').textContent = itemLabel;
    $('#qty-input').value = 1;
    updateTotalPrice();
    show('#quantity-modal');
}

function closeQuantityModal() {
    hide('#quantity-modal');
    selectedItem = null;
}

function changeQty(delta) {
    let input = $('#qty-input');
    let val = parseInt(input.value) + delta;
    if (val < 1) val = 1;
    if (val > 99) val = 99;
    input.value = val;
    updateTotalPrice();
}

function updateTotalPrice() {
    let qty = parseInt($('#qty-input').value) || 1;
    $('#total-price').textContent = (qty * selectedPrice).toFixed(2);
}

function confirmPurchase() {
    if (!selectedItem) return;

    let qty = parseInt($('#qty-input').value) || 1;

    post('buyItem', {
        item: selectedItem.name,
        quantity: qty,
        price: selectedPrice * qty
    });

    closeQuantityModal();
}

/* Plant Menu Functions */
function updatePlantUI(plant) {
    if (!plant) return;

    // Strain label
    document.getElementById('plant-label').innerText = plant.label || 'Unknown Strain';

    // Growth
    const growth = Math.floor(plant.growth || 0);
    document.getElementById('growth-bar').style.width = growth + '%';
    document.getElementById('growth-percent').innerText = growth + '%';

    // Water
    const water = Math.floor(plant.water || 0);
    document.getElementById('water-bar').style.width = water + '%';
    document.getElementById('water-percent').innerText = water + '%';

    // Quality
    const quality = plant.quality || 100;
    document.getElementById('quality-bar').style.width = quality + '%';
    document.getElementById('quality-percent').innerText = quality + '%';

    // Time Remaining
    const timeRem = Math.ceil(plant.timeRemaining || 0);
    if (timeRem > 60) {
        const hours = Math.floor(timeRem / 60);
        const mins = timeRem % 60;
        document.getElementById('time-remaining').innerText = hours + 'h ' + mins + 'm';
    } else {
        document.getElementById('time-remaining').innerText = timeRem + ' min';
    }

    // Status
    let status = 'Growing';
    if (water < 20) {
        status = '⚠️ Needs Water!';
    } else if (growth >= 100) {
        status = '✅ Ready to Harvest!';
    } else if (plant.fertilized == 1) {
        status = '⚡ Fertilized (Bonus Growth)';
    } else if (growth >= 50) {
        status = 'Maturing';
    }
    document.getElementById('plant-status').innerText = status;

    // Fertilize button state
    const fertilizeBtn = document.getElementById('fertilize-btn');
    if (fertilizeBtn) {
        if (plant.fertilized == 1 || growth >= 100) {
            fertilizeBtn.classList.add('disabled');
            fertilizeBtn.innerText = "Fertilized";
        } else {
            fertilizeBtn.classList.remove('disabled');
            fertilizeBtn.innerText = "Fertilize";
        }
    }

    // Water button state - disable when water is at 100%
    const waterBtn = document.getElementById('water-btn');
    if (waterBtn) {
        if (water >= 100) {
            waterBtn.classList.add('disabled');
        } else {
            waterBtn.classList.remove('disabled');
        }
    }

    // Harvest button availability
    const harvestBtn = document.getElementById('harvest-btn');
    if (growth >= 100) {
        harvestBtn.classList.remove('disabled');
    } else {
        harvestBtn.classList.add('disabled');
    }
}

function doAction(action) {
    if (!currentPlantId) return;

    post('plantAction', {
        plantId: currentPlantId,
        action: action
    });

    if (action === 'destroy' || action === 'harvest') {
        closePlantMenu();
    }
}

function closePlantMenu() {
    hide('#plant-menu');
    post('close');
}

function showToast(msg) {
    const t = document.getElementById('toast');
    if (t) {
        t.innerText = msg;
        show(t);
        setTimeout(function() {
            hide(t);
        }, 3000);
    }
}

function acceptOffer() {
    hide('#selling-interaction');
    post('sell_accept');
}

function declineOffer() {
    hide('#selling-interaction');
    post('sell_decline');
}
