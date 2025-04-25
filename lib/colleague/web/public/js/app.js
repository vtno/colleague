document.addEventListener("DOMContentLoaded", function () {
  // Handle file input display
  const fileInput = document.getElementById("file");
  if (fileInput) {
    fileInput.addEventListener("change", function () {
      const fileName = this.value.split("\\").pop();
      if (fileName) {
        const label =
          this.nextElementSibling ||
          document.querySelector('label[for="file"]');
        if (label) {
          label.textContent = `Selected: ${fileName}`;
        }
      }
    });
  }

  // Add loading indicator to forms
  const forms = document.querySelectorAll("form");
  forms.forEach((form) => {
    form.addEventListener("submit", function () {
      const button = this.querySelector('button[type="submit"]');
      if (button) {
        button.disabled = true;
        button.innerHTML = "Processing...";
      }
    });
  });
});
