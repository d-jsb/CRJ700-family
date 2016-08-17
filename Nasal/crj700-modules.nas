#
# CRJ 700 nasal modules loader 
# this file is included via CRJ700-main.xml into namespace CRJ700
#
var EFIS_namespace = "CRJ_EFIS";
var crj_efis = modules.Module.new(EFIS_namespace);
crj_efis.setDebug(0);
crj_efis.setlistenerRuntimeDefault(0);
crj_efis.setFilePath(getprop("/sim/aircraft-dir")~"/Nasal");
crj_efis.setMainFile("CRJ700-efis.nas");
crj_efis.load();

var speedbook_namespace = "CRJ_SPEEDBOOK";
var crj_speedbook = modules.Module.new(speedbook_namespace);
crj_speedbook.setDebug(0);
crj_speedbook.setlistenerRuntimeDefault(0);
crj_speedbook.setFilePath(getprop("/sim/aircraft-dir")~"/Nasal");
crj_speedbook.setMainFile("speedbooklet.nas");
crj_speedbook.load();

var adc_conf_namespace = "CRJ_ADC_CONF";
var crj_adc_conf = modules.Module.new(adc_conf_namespace);
crj_adc_conf.setDebug(0);
crj_adc_conf.setlistenerRuntimeDefault(0);
crj_adc_conf.setFilePath(getprop("/sim/aircraft-dir")~"/Nasal");
crj_adc_conf.setMainFile("adc-conf.nas");
crj_adc_conf.load();
