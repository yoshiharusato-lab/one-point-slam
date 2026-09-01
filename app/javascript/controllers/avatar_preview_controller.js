import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "image", "status"]

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.imageTarget.src = URL.createObjectURL(file)
    if (this.hasStatusTarget) this.statusTarget.textContent = "画像未保存"
    this.inputTarget.form.requestSubmit()
  }
}
