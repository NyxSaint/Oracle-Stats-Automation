-- Create table
create table SYS.GBD_BITACORA_ESTAT
(
  grupo   NUMBER,
  paso    NUMBER,
  proceso VARCHAR2(50),
  hi      VARCHAR2(50),
  hf      VARCHAR2(50)
)
tablespace TSD_DATA
  pctfree 10
  initrans 4
  maxtrans 255
  storage
  (
    initial 16K
    next 1M
    minextents 1
    maxextents unlimited
  );
