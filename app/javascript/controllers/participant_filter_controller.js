import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "filterButton"]

  filter(event) {
    const filter = event.currentTarget.dataset.filterValue

    this.filterButtonTargets.forEach((button) => {
      const active = button.dataset.filterValue === filter
      button.classList.toggle("bg-emerald-600", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("bg-slate-100", !active)
      button.classList.toggle("text-slate-600", !active)
    })

    this.rowTargets.forEach((row) => {
      const visible = filter === "all" || row.dataset[filter] === "true"
      row.classList.toggle("hidden", !visible)
    })
  }
}
