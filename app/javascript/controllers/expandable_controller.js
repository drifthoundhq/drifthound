import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]

  toggle(event) {
    if (!this.hasContentTarget) return
    if (event?.target.closest("[data-expandable-ignore]")) return

    const isHidden = this.contentTarget.hidden
    this.contentTarget.hidden = !isHidden
    this.element.classList.toggle("expanded", isHidden)
  }
}
