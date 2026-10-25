import { useEffect, useRef } from "react";
import {
  AndroidLogo,
  GooglePlayLogo,
  ArrowRight,
  Leaf,
  Jar,
  X,
} from "@phosphor-icons/react";

const APK = "/downloads/valora-android-preview.apk";

function Downloads({ onStore }) {
  return (
    <div className="downloads">
      <a
        className="download primary"
        href={APK}
        download="valora-android-preview.apk"
      >
        <AndroidLogo size={27} weight="fill" aria-hidden="true" />
        <span>
          <strong>Download APK</strong>
          <small>Android preview</small>
        </span>
      </a>
      <button className="download secondary" onClick={onStore}>
        <GooglePlayLogo size={27} weight="fill" aria-hidden="true" />
        <span>
          <strong>Google Play</strong>
          <small>Coming soon</small>
        </span>
      </button>
    </div>
  );
}

function useLandingMotion(root) {
  useEffect(() => {
    const page = root.current;
    const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
    const desktop = window.matchMedia("(min-width: 761px)");
    const stage = page.querySelector(".phone-stage");
    const hero = page.querySelector(".hero");
    let observer;
    let frame = 0;
    let listening = false;
    let heroVisible = true;
    const update = () => {
      frame = 0;
      if (!preference.matches && desktop.matches && heroVisible) {
        const progress = Math.min(
          1,
          Math.max(0, -hero.getBoundingClientRect().top / hero.offsetHeight),
        );
        stage.style.setProperty("--hero-drift", `${-24 * progress}px`);
      }
    };
    const scroll = () => {
      if (!frame && heroVisible) frame = requestAnimationFrame(update);
    };
    const clear = () => {
      observer?.disconnect();
      cancelAnimationFrame(frame);
      frame = 0;
      window.removeEventListener("scroll", scroll);
      listening = false;
      page.classList.remove("motion-enabled");
      page
        .querySelectorAll(".reveal-pending")
        .forEach((el) => el.classList.remove("reveal-pending"));
      stage.style.removeProperty("--hero-drift");
    };
    const configure = () => {
      clear();
      if (preference.matches) return;
      page.classList.add("motion-enabled");
      if ("IntersectionObserver" in window) {
        observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.target === hero) {
                heroVisible = entry.isIntersecting;
                if (heroVisible) scroll();
              } else if (entry.isIntersecting) {
                entry.target.classList.remove("reveal-pending");
                entry.target.classList.add("revealed");
                observer.unobserve(entry.target);
              }
            });
          },
          { threshold: 0.12 },
        );
        page.querySelectorAll("[data-reveal]").forEach((el) => {
          if (
            !el.classList.contains("revealed") &&
            el.getBoundingClientRect().top > window.innerHeight * 0.85
          ) {
            el.classList.add("reveal-pending");
            observer.observe(el);
          }
        });
        observer.observe(hero);
      }
      if (desktop.matches) {
        window.addEventListener("scroll", scroll, { passive: true });
        listening = true;
        scroll();
      }
    };
    const resize = () => {
      if (preference.matches) return;
      if (desktop.matches && !listening) {
        window.addEventListener("scroll", scroll, { passive: true });
        listening = true;
      } else if (!desktop.matches && listening) {
        window.removeEventListener("scroll", scroll);
        cancelAnimationFrame(frame);
        frame = 0;
        listening = false;
        stage.style.removeProperty("--hero-drift");
      }
      if (desktop.matches) scroll();
    };
    configure();
    preference.addEventListener("change", configure);
    desktop.addEventListener("change", resize);
    return () => {
      clear();
      preference.removeEventListener("change", configure);
      desktop.removeEventListener("change", resize);
    };
  }, [root]);
}

export function App() {
  const root = useRef(null);
  const storeDialog = useRef(null);
  const openStore = () => storeDialog.current.showModal();
  useLandingMotion(root);

  return (
    <div ref={root} className="landing">
      <a className="skip-link" href="#your-food">
        Skip to content
      </a>
      <main>
        <section className="hero" id="top" aria-labelledby="hero-heading">
          <img
            className="hero-backdrop"
            src="/assets/hero-kitchen.webp"
            alt=""
            width="1600"
            height="1400"
            fetchPriority="high"
          />
          <header className="navigation">
            <a className="wordmark" href="#top" aria-label="Valora home">
              valora<span>.</span>
            </a>
            <nav aria-label="Main navigation">
              <a href="#your-food">How it works</a>
              <a href="#pantry" className="food-nav">
                Your food
              </a>
              <a className="nav-download" href="#download">
                Download
              </a>
            </nav>
          </header>
          <div className="hero-copy">
            <h1 id="hero-heading">
              <span className="line">
                <span>Eat well.</span>
              </span>
              <span className="line">
                <span>Think less.</span>
              </span>
            </h1>
            <p>
              Your meals, pantry and grocery plans.
              <br />
              In one personal space.
            </p>
            <Downloads onStore={openStore} />
          </div>
          <div
            className="phone-stage"
            aria-label="Preview of Valora’s meal plan, personal space and pantry"
          >
            <div className="phone phone-plan">
              <img
                src="/assets/phone-plan.webp"
                alt="Valora meal plan with breakfast, chicken and rice for lunch, and vegetable pasta for dinner"
                width="887"
                height="1774"
              />
            </div>
            <div className="phone phone-home">
              <img
                src="/assets/phone-home.webp"
                alt="Valora personal space with shortcuts to your plan, pantry and food rules"
                width="887"
                height="1774"
              />
            </div>
            <div className="phone phone-pantry">
              <img
                src="/assets/phone-pantry.webp"
                alt="Valora pantry with ingredients and remaining quantities"
                width="887"
                height="1774"
              />
            </div>
          </div>
        </section>
        <section
          className="editorial"
          id="your-food"
          aria-labelledby="food-heading"
        >
          <div className="editorial-inner">
            <div className="meals-story">
              <div data-reveal className="section-heading">
                <p className="eyebrow">YOUR FOOD, YOUR WAY</p>
                <h2 id="food-heading">
                  A little less planning.
                  <br />A lot more living.
                </h2>
              </div>
              <div className="meal-content" data-reveal>
                <div className="photo-wrap meal-photo">
                  <img
                    src="/assets/meal-salmon.webp"
                    alt="Grilled salmon with rice and colourful roasted vegetables"
                    width="800"
                    height="800"
                    loading="lazy"
                  />
                </div>
                <div className="story-copy">
                  <span className="story-icon">
                    <Leaf size={25} aria-hidden="true" />
                  </span>
                  <h3>
                    Meals that fit
                    <br />
                    your life
                  </h3>
                  <p>
                    Plan simple, delicious meals around what you like, with
                    ideas inspired by everyday Indian and global flavours.
                  </p>
                  <a
                    className="text-link"
                    href="#meal-details"
                    onClick={() => {
                      document.getElementById("meal-details").open = true;
                    }}
                  >
                    Explore meal planning{" "}
                    <ArrowRight size={18} aria-hidden="true" />
                  </a>
                </div>
              </div>
              <details id="meal-details" className="feature-details">
                <summary>Make the plan your own</summary>
                <p>
                  Share what you eat, what you avoid, your budget and cooking
                  time. Review each day’s meals and try a different cuisine or
                  something quicker. You choose what stays.
                </p>
              </details>
            </div>
            <div className="pantry-story" id="pantry" data-reveal>
              <div className="photo-wrap pantry-photo">
                <img
                  src="/assets/pantry-ingredients.webp"
                  alt="Pantry jars, eggs and fresh vegetables on a kitchen counter"
                  width="1000"
                  height="600"
                  loading="lazy"
                />
              </div>
              <div className="pantry-copy">
                <span className="story-icon">
                  <Jar size={25} aria-hidden="true" />
                </span>
                <div className="story-copy">
                  <h3>Use what you have</h3>
                  <p>
                    Keep track of your pantry and get meal ideas that make the
                    most of what’s already in your kitchen.
                  </p>
                  <a
                    className="text-link"
                    href="#pantry-details"
                    onClick={() => {
                      document.getElementById("pantry-details").open = true;
                    }}
                  >
                    Explore pantry management{" "}
                    <ArrowRight size={18} aria-hidden="true" />
                  </a>
                </div>
              </div>
              <details id="pantry-details" className="feature-details">
                <summary>A little more clarity in your kitchen</summary>
                <p>
                  Record ingredients and quantities, then update what’s left
                  when you cook. What’s in your pantry and what you’ve eaten
                  stay separate, so your plan starts with the right information.
                </p>
              </details>
            </div>
          </div>
        </section>
        <section
          id="download"
          className="download-section"
          aria-labelledby="download-heading"
        >
          <div className="download-backdrop">
            <img
              src="/assets/download-table.webp"
              alt=""
              width="1600"
              height="440"
              loading="lazy"
            />
          </div>
          <div className="download-content" data-reveal>
            <h2 id="download-heading">Make room for better meals.</h2>
            <Downloads onStore={openStore} />
          </div>
        </section>
      </main>
      <footer>
        <a className="wordmark" href="#top" aria-label="Valora home">
          valora<span>.</span>
        </a>
        <nav aria-label="Footer navigation">
          <a href="#your-food">How it works</a>
          <a href="#pantry">Your food</a>
          <a href="#download">Download</a>
        </nav>
        <p>Preview app. Live AI and ordering are coming later.</p>
      </footer>
      <dialog
        ref={storeDialog}
        className="store-dialog"
        aria-labelledby="store-heading"
        onClick={(event) => {
          const bounds = event.currentTarget.getBoundingClientRect();
          if (
            event.target === event.currentTarget &&
            (event.clientX < bounds.left ||
              event.clientX > bounds.right ||
              event.clientY < bounds.top ||
              event.clientY > bounds.bottom)
          )
            event.currentTarget.close();
        }}
      >
        <button
          className="close-dialog"
          aria-label="Close"
          onClick={() => storeDialog.current.close()}
        >
          <X size={22} />
        </button>
        <GooglePlayLogo size={36} weight="fill" aria-hidden="true" />
        <h2 id="store-heading">Coming to Google Play.</h2>
        <p>
          Valora isn’t on the Play Store yet. You can try the Android preview
          APK now.
        </p>
        <a
          className="download primary"
          href={APK}
          download="valora-android-preview.apk"
        >
          <AndroidLogo size={25} weight="fill" aria-hidden="true" />
          <span>
            <strong>Download APK</strong>
            <small>Android preview · debug build</small>
          </span>
        </a>
        <p className="dialog-note">
          This preview demonstrates the app experience. Live AI, payments and
          ordering aren’t connected.
        </p>
      </dialog>
    </div>
  );
}
