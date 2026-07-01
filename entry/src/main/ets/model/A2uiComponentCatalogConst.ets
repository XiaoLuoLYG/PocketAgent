export const AIPHONE_COMPONENT_CATALOG_JSON: string =
  '[' +
    '{"name":"SurfaceRoot","role":"布局组件","usage":"surface 根节点，通过 child 或 children 指向真实存在的组件 id"},' +
    '{"name":"Column","role":"布局组件","usage":"纵向容器，通过 children 排列真实存在的子组件 id"},' +
    '{"name":"Row","role":"布局组件","usage":"横向容器，通过 children 排列真实存在的子组件 id，不要把按钮文案或数据值直接写进 children"},' +
    '{"name":"Text","role":"内容组件","usage":"展示简短文本说明，使用 text 或 body 承载内容"},' +
    '{"name":"InfoRows","role":"内容组件","usage":"展示 label/value 信息行，使用 dataPath 绑定 rows 数据"},' +
    '{"name":"ActionBar","role":"交互组件","usage":"展示一组可点击操作，按钮必须写入 actions，不要使用 children"},' +
    '{"name":"ErrorNotice","role":"内容组件","usage":"展示错误、限制或无法执行的提示"},' +
    '{"name":"ThinkingStream","role":"状态组件","usage":"展示工具调用或处理中状态，通常绑定 /thoughts"},' +
    '{"name":"ThinkingCard","role":"状态组件","usage":"展示处理中摘要卡片，通常由客户端状态补齐"},' +
    '{"name":"TravelOptions","role":"业务组件","usage":"展示工具返回的综合出行方案，只能绑定 /travelOptions"},' +
    '{"name":"TrainOptions","role":"业务组件","usage":"展示工具返回的车次结果，只能绑定 /trains"},' +
    '{"name":"FlightBoard","role":"业务组件","usage":"展示工具返回的航班结果，只能绑定 /flights"},' +
    '{"name":"FoodChoices","role":"业务组件","usage":"展示工具返回的餐饮结果，只能绑定 /foods"},' +
    '{"name":"SocialHub","role":"业务组件","usage":"展示社交聚合数据，只能绑定 /socialHub/items、/socialHub/selected、/socialHub/draft 或 /socialHub/connections"},' +
    '{"name":"ToolConnectCard","role":"动态工具接入组件","usage":"展示远程 MCP/API 工具接入状态、认证字段、来源和测试/启用操作，只能绑定 /dynamicToolConnect"},' +
    '{"name":"GenericToolResults","role":"动态工具结果组件","usage":"展示通用 MCP tools/call 真实返回摘要，只能绑定 /genericToolResults"},' +
    '{"name":"ConfirmPanel","role":"兼容占位组件","usage":"当前 renderer 不展示，模型不要主动生成"}' +
  ']';
