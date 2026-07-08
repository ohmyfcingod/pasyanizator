  <items xsi:type="form:FormField">
    <name>{{ИМЯ_РЕКВ}}</name>
    <id>{{ID}}</id>
    <visible>true</visible>
    <enabled>true</enabled>
    <userVisible>
      <common>true</common>
    </userVisible>
    <dataPath xsi:type="form:DataPath">
      <segments>Объект.{{ИМЯ_РЕКВ}}</segments>
    </dataPath>
    <extendedTooltip>
      <name>{{ИМЯ_РЕКВ}}РасширеннаяПодсказка</name>
      <id>{{ID2}}</id>
      <type>Label</type>
      <autoMaxWidth>true</autoMaxWidth>
      <autoMaxHeight>true</autoMaxHeight>
      <extInfo xsi:type="form:LabelDecorationExtInfo">
        <horizontalAlign>Left</horizontalAlign>
      </extInfo>
    </extendedTooltip>
    <contextMenu>
      <name>{{ИМЯ_РЕКВ}}КонтекстноеМеню</name>
      <id>{{ID3}}</id>
      <autoFill>true</autoFill>
    </contextMenu>
    <type>InputField</type>
    <editMode>Auto</editMode>
    <showInHeader>true</showInHeader>
    <headerHorizontalAlign>Left</headerHorizontalAlign>
    <showInFooter>true</showInFooter>
    <extInfo xsi:type="form:InputFieldExtInfo">
      <autoMaxWidth>true</autoMaxWidth>
      <autoMaxHeight>true</autoMaxHeight>
      <wrap>true</wrap>
    </extInfo>
  </items>
