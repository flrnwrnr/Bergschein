const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".site-nav");

if (toggle && nav) {
  toggle.addEventListener("click", () => {
    const isOpen = nav.classList.toggle("is-open");
    toggle.setAttribute("aria-expanded", String(isOpen));
  });
}

const slider = document.querySelector(".slider");

if (slider) {
  const track = slider.querySelector(".slider-track");
  const slides = Array.from(slider.querySelectorAll(".shot-card"));
  const prevButton = slider.querySelector(".slider-button-prev");
  const nextButton = slider.querySelector(".slider-button-next");
  const dotsContainer = document.querySelector(".slider-dots");
  let currentIndex = 0;

  const getVisibleSlides = () => {
    if (window.innerWidth <= 560) return 1;
    if (window.innerWidth <= 980) return 2;
    return 3;
  };

  const getMaxIndex = () => Math.max(0, slides.length - getVisibleSlides());

  const renderDots = () => {
    if (!dotsContainer) return;
    const pages = getMaxIndex() + 1;
    dotsContainer.innerHTML = "";

    for (let index = 0; index < pages; index += 1) {
      const dot = document.createElement("button");
      dot.type = "button";
      dot.className = `slider-dot${index === currentIndex ? " is-active" : ""}`;
      dot.setAttribute("aria-label", `Gehe zu Screenshot ${index + 1}`);
      dot.addEventListener("click", () => {
        currentIndex = index;
        updateSlider();
      });
      dotsContainer.appendChild(dot);
    }
  };

  const updateSlider = () => {
    const maxIndex = getMaxIndex();
    currentIndex = Math.min(currentIndex, maxIndex);

    const slideWidth = slides[0]?.getBoundingClientRect().width ?? 0;
    const gap = 18;
    track.style.transform = `translateX(-${currentIndex * (slideWidth + gap)}px)`;

    if (prevButton) prevButton.disabled = currentIndex === 0;
    if (nextButton) nextButton.disabled = currentIndex === maxIndex;

    if (dotsContainer) {
      Array.from(dotsContainer.children).forEach((dot, index) => {
        dot.classList.toggle("is-active", index === currentIndex);
      });
    }
  };

  prevButton?.addEventListener("click", () => {
    currentIndex = Math.max(0, currentIndex - 1);
    updateSlider();
  });

  nextButton?.addEventListener("click", () => {
    currentIndex = Math.min(getMaxIndex(), currentIndex + 1);
    updateSlider();
  });

  window.addEventListener("resize", () => {
    renderDots();
    updateSlider();
  });

  renderDots();
  updateSlider();
}
