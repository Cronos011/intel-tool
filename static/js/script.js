const subcategories = {
    "Piracy and Crime": ["Cargo Piracy", "Kidnapping", "Blackmail"],
    "Trading and Economy": ["Commodity Trading", "Black Market Deals"],
};

document.getElementById("typeOfIncident").addEventListener("change", function () {
    const selectedType = this.value;
    const subcategorySelect = document.getElementById("subcategory");
    subcategorySelect.innerHTML = "";

    if (subcategories[selectedType]) {
        subcategories[selectedType].forEach(subcategory => {
            const option = document.createElement("option");
            option.value = subcategory;
            option.textContent = subcategory;
            subcategorySelect.appendChild(option);
        });
    }
});
