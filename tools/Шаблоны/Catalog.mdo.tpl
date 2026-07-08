<?xml version="1.0" encoding="UTF-8"?>
<mdclass:Catalog xmlns:mdclass="http://g5.1c.ru/v8/dt/metadata/mdclass" uuid="{{UUID}}">
  <producedTypes>
    <objectType typeId="{{UUID_OBJECT_T}}" valueTypeId="{{UUID_OBJECT_V}}"/>
    <refType typeId="{{UUID_REF_T}}" valueTypeId="{{UUID_REF_V}}"/>
    <selectionType typeId="{{UUID_SELECTION_T}}" valueTypeId="{{UUID_SELECTION_V}}"/>
    <listType typeId="{{UUID_LIST_T}}" valueTypeId="{{UUID_LIST_V}}"/>
    <managerType typeId="{{UUID_MANAGER_T}}" valueTypeId="{{UUID_MANAGER_V}}"/>
  </producedTypes>
  <name>{{ИМЯ}}</name>
  <synonym>
    <key>ru</key>
    <value>{{СИНОНИМ}}</value>
  </synonym>
  <comment>Пасьянизатор из вида {{ВИД_UUID}}</comment>
  <useStandardCommands>true</useStandardCommands>
  <inputByString>Catalog.{{ИМЯ}}.StandardAttribute.Code</inputByString>
  <inputByString>Catalog.{{ИМЯ}}.StandardAttribute.Description</inputByString>
  <fullTextSearchOnInputByString>DontUse</fullTextSearchOnInputByString>
  <createOnInput>Use</createOnInput>
  <fullTextSearch>Use</fullTextSearch>
  <levelCount>2</levelCount>
  <foldersOnTop>true</foldersOnTop>
  <codeLength>9</codeLength>
  <descriptionLength>150</descriptionLength>
  <codeType>String</codeType>
  <codeAllowedLength>Variable</codeAllowedLength>
  <checkUnique>true</checkUnique>
  <autonumbering>true</autonumbering>
  <defaultPresentation>AsDescription</defaultPresentation>
  <editType>InDialog</editType>
  <choiceMode>BothWays</choiceMode>
{{DEFAULT_OBJECT_FORM}}  <attributes uuid="{{UUID_ВИДДОКУМЕНТА}}">
    <name>ВидДокумента</name>
    <synonym>
      <key>ru</key>
      <value>Вид документа</value>
    </synonym>
    <type>
      <types>CatalogRef.ВидыДокументов</types>
    </type>
    <fillChecking>ShowError</fillChecking>
    <indexing>Index</indexing>
  </attributes>
{{РЕКВИЗИТЫ}}
{{ТАБЛИЧНЫЕ_ЧАСТИ}}{{ФОРМЫ}}
</mdclass:Catalog>
