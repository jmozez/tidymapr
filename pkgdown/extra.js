// downlit gives example plots on reference pages an empty alt attribute.
// Describe each one by the example code that produced it.
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll(".r-plt img").forEach(function (img) {
    if (img.getAttribute("alt")) return;
    var code = [];
    var el = img.parentElement.previousElementSibling;
    while (el && el.classList.contains("r-in")) {
      code.unshift(el.textContent.trim());
      el = el.previousElementSibling;
    }
    var text = code.join(" ").replace(/\s+/g, " ");
    if (text.length > 200) text = "\u2026" + text.slice(-200);
    img.setAttribute("alt", text ? "Plot produced by the example code: " + text
                                 : "Example plot");
  });
});
