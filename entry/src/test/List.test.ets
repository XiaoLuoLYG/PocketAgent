import localUnitTest from './LocalUnit.test';
import a2uiParserTest from './A2uiParser.test';
import localModelClientTest from './LocalModelClient.test';
import socialBridgeTest from './SocialBridge.test';
import toolGatewayClientTest from './ToolGatewayClient.test';
import a2uiHomeStateTest from './A2uiHomeState.test';
import a2uiRenderDataTest from './A2uiRenderData.test';
import a2uiHomeToolRequestTest from './A2uiHomeToolRequest.test';
import a2uiBusinessDataTest from './A2uiBusinessData.test';
import a2uiStyleLabMocksTest from './A2uiStyleLabMocks.test';
import a2uiActionBarLayoutTest from './A2uiActionBarLayout.test';
import a2uiHomeMotionTest from './A2uiHomeMotion.test';
import a2uiTrainOptionsStateTest from './A2uiTrainOptionsState.test';
import a2uiButtonStyleTest from './A2uiButtonStyle.test';
import a2uiHomeLayoutTest from './A2uiHomeLayout.test';
import a2uiHomeDebugSettingsTest from './A2uiHomeDebugSettings.test';
import a2uiPartialUpdatePlannerTest from './A2uiPartialUpdatePlanner.test';

export default function testsuite() {
  localUnitTest();
  a2uiParserTest();
  localModelClientTest();
  socialBridgeTest();
  toolGatewayClientTest();
  a2uiHomeStateTest();
  a2uiRenderDataTest();
  a2uiHomeToolRequestTest();
  a2uiBusinessDataTest();
  a2uiStyleLabMocksTest();
  a2uiActionBarLayoutTest();
  a2uiHomeMotionTest();
  a2uiTrainOptionsStateTest();
  a2uiButtonStyleTest();
  a2uiHomeLayoutTest();
  a2uiHomeDebugSettingsTest();
  a2uiPartialUpdatePlannerTest();
}
