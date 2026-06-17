import { A2uiAction } from '../../../model/A2uiTypes';
import {
  A2UI_DIALOG_ACTION_GAP,
  A2UI_DIALOG_ACTION_SIDE_PADDING,
  actionRenderKey,
  usesDialogActionLayout
} from '../style/A2uiActionBarLayout';
import { A2uiButtonView } from './common/A2uiButtonView';

@Component
export struct ActionBarView {
  @Prop actions: A2uiAction[] = [];
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private useDialogLayout(): boolean {
    return usesDialogActionLayout(this.actions.length);
  }

  private actionTone(action: A2uiAction): string {
    if (action.variant === 'activated' || action.variant === 'deactivated') {
      return action.variant;
    }
    return action.variant;
  }

  private actionActive(action: A2uiAction): boolean {
    return action.variant === 'activated';
  }

  build() {
    if (this.actions.length > 0) {
      if (this.useDialogLayout()) {
        Row() {
          ForEach(this.actions, (action: A2uiAction, index: number) => {
            A2uiButtonView({
              label: action.label,
              shape: 'pill',
              tone: this.actionTone(action),
              active: this.actionActive(action),
              isEnabled: !this.isBusy,
              fill: true
            })
              .onClick(() => {
                if (this.isBusy) {
                  return;
                }
                this.onAction(action);
              })
              .layoutWeight(1)
              .margin({ right: index === 0 ? A2UI_DIALOG_ACTION_GAP : 0 })
          }, (action: A2uiAction) => actionRenderKey(action))
        }
        .width('100%')
        .padding({ left: A2UI_DIALOG_ACTION_SIDE_PADDING, right: A2UI_DIALOG_ACTION_SIDE_PADDING })
        .margin({ top: 12 })
      } else {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          ForEach(this.actions, (action: A2uiAction) => {
            A2uiButtonView({
              label: action.label,
              shape: 'pill',
              tone: this.actionTone(action),
              active: this.actionActive(action),
              isEnabled: !this.isBusy
            })
              .onClick(() => {
                if (this.isBusy) {
                  return;
                }
                this.onAction(action);
              })
              .margin({ right: 8, top: 10 })
          }, (action: A2uiAction) => actionRenderKey(action))
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
  }
}
