import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["main", "thumb", "prevButton", "nextButton", "thumbStrip"]

  connect() {
    this.index = 0
    this.apply()
  }

  select(event) {
    const idx = Number(event.currentTarget.dataset.index)
    if (Number.isNaN(idx)) return
    this.index = idx
    this.apply({ focusThumb: true })
  }

  prev() {
    if (this.index <= 0) return
    this.index -= 1
    this.apply({ focusThumb: true })
  }

  next() {
    if (this.index >= this.thumbTargets.length - 1) return
    this.index += 1
    this.apply({ focusThumb: true })
  }

  keydown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
  }

  scrollThumbsLeft() {
    if (!this.hasThumbStripTarget) return
    this.thumbStripTarget.scrollBy({ left: -280, behavior: "smooth" })
  }

  scrollThumbsRight() {
    if (!this.hasThumbStripTarget) return
    this.thumbStripTarget.scrollBy({ left: 280, behavior: "smooth" })
  }

  apply({ focusThumb } = {}) {
    const active = this.thumbTargets[this.index]
    if (!active) return

    this.mainTarget.src = active.dataset.full
    this.mainTarget.alt = active.dataset.alt || ""

    this.thumbTargets.forEach((el, i) => {
      const isActive = i === this.index
      el.classList.toggle("ring-2", isActive)
      el.classList.toggle("ring-amber-500", isActive)
      el.classList.toggle("border-amber-300", isActive)
      el.classList.toggle("border-slate-200", !isActive)
      el.setAttribute("aria-current", isActive ? "true" : "false")
    })

    if (this.hasPrevButtonTarget) {
      const disabled = this.index <= 0
      this.prevButtonTarget.disabled = disabled
      this.prevButtonTarget.classList.toggle("opacity-40", disabled)
      this.prevButtonTarget.classList.toggle("cursor-not-allowed", disabled)
    }

    if (this.hasNextButtonTarget) {
      const disabled = this.index >= this.thumbTargets.length - 1
      this.nextButtonTarget.disabled = disabled
      this.nextButtonTarget.classList.toggle("opacity-40", disabled)
      this.nextButtonTarget.classList.toggle("cursor-not-allowed", disabled)
    }

    if (focusThumb) {
      active.scrollIntoView({ block: "nearest", inline: "center" })
    }
  }
}

