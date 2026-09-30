import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "mutePlanNoise"

// Lets each viewer grey out "(known after apply)" values in plan output.
// The choice is remembered in this browser only.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    if (!this.hasToggleTarget) return

    this.toggleTarget.checked = this.readPreference()
    this.apply()
  }

  change() {
    this.apply()
    try {
      localStorage.setItem(STORAGE_KEY, this.toggleTarget.checked ? "true" : "false")
    } catch (e) {
      // Storage can be unavailable (private mode, blocked site data); the
      // toggle still works for this page view.
    }
  }

  apply() {
    this.element.classList.toggle("mute-plan-noise", this.toggleTarget.checked)
  }

  readPreference() {
    try {
      return localStorage.getItem(STORAGE_KEY) === "true"
    } catch (e) {
      return false
    }
  }
}
