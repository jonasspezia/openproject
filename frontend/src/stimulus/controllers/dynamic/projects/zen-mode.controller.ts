import { ApplicationController } from 'stimulus-use';

export default class OpProjectsZenModeController extends ApplicationController {
  static targets = ['button'];
  inZenMode = false;

  declare readonly buttonTarget:HTMLElement;

  connect() {
    document.addEventListener('fullscreenchange', this.fullscreenChangeEventHandler.bind(this));
  }

  disconnect() {
    super.disconnect();
    document.removeEventListener('fullscreenchange', this.fullscreenChangeEventHandler.bind(this));
  }

  fullscreenChangeEventHandler() {
    this.inZenMode = !this.inZenMode;
    this.dispatchZenModeStatus();
  }

  dispatchZenModeStatus() {
    // Create a new custom event
    const event = new CustomEvent('zenModeToggled', {
      detail: {
        active: this.inZenMode,
      },
    });
    // Dispatch the custom event
    window.dispatchEvent(event);
  }

  private deactivateZenMode() {
    if (document.exitFullscreen) {
      void document.exitFullscreen();
    }
  }

  private activateZenMode() {
    if (document.documentElement.requestFullscreen) {
      void document.documentElement.requestFullscreen();
    }
  }

  public performAction() {
    if (this.inZenMode) {
      this.deactivateZenMode();
    } else {
      this.activateZenMode();
    }
  }
}
