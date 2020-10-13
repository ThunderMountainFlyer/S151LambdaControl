'--------------------------------------------------------------------
' ANWENDUNG: SERVOANSTEUERUNG MIT DA1 und DA2
'
'--------------------------------------------------------------------
' Dieses Beispiel zeigt die Vorgehensweise um die beiden PWM DA-WANDLER
' zur Ansteuerung von Servos zu konfigurieren. Die Konfiguration
' erfolgt über ein KONFIGURATIONS-REGISTER, das wie alle erweiterten
' Funktionen Bestandteil eines OBJECTS ( hier CONFIG)ist. Das Register
' kann gelesen u. beschrieben werden.
'--------------------------------------------------------------------
' Das Konfigurations-Register bietet folgende Optionen.
'
' Bit 0       Schaltet beide PWM-DACs in den SERVO-Mode
' Bit 1       Schaltet den Frequenzzähler 1 in den EREIGNISZÄHLER Mode
' Bit 2       Schaltet den Frequenzzähler 2 in den EREIGNISZÄHLER Mode
' Bit 3       Aktiviert die PULLUP-Widerstände an PORT 1 bis 8
' Bit 4       Aktiviert die PULLUP-Widerstände an PORT 9 bis 15
' Bit 5       Zeigt an wenn die interne Uhr mit DCF77 synchronisiert wurde
' Bit 6       Signalisiert einen Fehler bei der IIC-Kommunikation
' Bit 7       Zustand der Start-Taste
'---------------------------------------------------------------------
' Einzelheiten darüber finden Sie in den Demos zu den EXTENDED FUNCTIONS
' - LCD OBJECT       über die zusätzlichen Funktionen für das LCd
' - CONFIG OBJECT    über die zusätzlichen Funktionen für die Konfiguraton
'
' Beschreibung:
' Wenn die beiden DA-Ausgänge (und das ist leider nur für beide gleichzeitig möglich)
' als SERVO-Treiber konfiguriert sind liefern sie ein für Servos übliches Signal
' mit einer Wiederholfrequenz von 50 Hz.
' Ein DA-Wert von Null entspricht einer Pulslänge von 1ms, ein Wert von 255
' einer Impulslänge von 2ms
' In diesem Beispiel werden die Einstellbereiche von DA1 u. DA2 antizyklisch
' durchfahren, der gerade aktuelle Wert wird im LCD angezeigt.
' Wenn Sie an DA1 u. DA2 jeweils ein SERVO anschliessen, sehen Sie den Stellbereich
' des Servos
' Beachten Sie bitte, dass der Wert für DA1 u. DA2 nicht aus diesen zurück
' gelesen werden kann.
' Der aktuelle Wert für jedes SERVO wird auf dem LCD ausgegeben.
'-----------------------------------------------------------------------

'--------------------------
'------ I/O PORTS ---------
'--------------------------
DEFINE Serv1        DA[1]
DEFINE Power        PORT[1]
DEFINE TSet         PORT[2]
DEFINE TUp          PORT[3]
DEFINE TDown        PORT[4]
DEFINE FanLevel1    PORT[5]  
DEFINE SDA          PORT[9]
DEFINE SCL          PORT[10]
DEFINE Light        PORT[16]
DEFINE LamdaVoltage AD[1]

'--------------------------
'---- SYSTEM MEMORY -------
'--------------------------


DEFINE ReferenceVoltage BYTE
DEFINE Tolerance        BYTE 
DEFINE MaxPosition      BYTE
DEFINE PowerOffTemp     BYTE  
DEFINE PowerOnTemp      BYTE

DEFINE Position         BYTE
DEFINE MenuItem         BYTE

DEFINE Temperatur       WORD
DEFINE ExhaustTemp      WORD
DEFINE AverageTemp      WORD
DEFINE TemperaturMSB    REF Temperatur AT BYTE[1]
DEFINE TemperaturLSB    REF Temperatur AT BYTE[2]

DEFINE Operation        BIT

'-------------------------------------------------
'-              Initialize system                -
'-------------------------------------------------

Power     = on     'pull up digital port2 to aktivate main power relais
FanLevel1 = on     'pull up digital port5 to aktivate fan dimmed with 100k (Level1)

ReferenceVoltage = 90    ' approx 7% oxigen
Tolerance        = 3     ' allowed deviation from reference bevor adjustment 
MaxPosition      = 140   ' maximum servo position for closed state
PowerOffTemp     = 100   ' if the average exhaust temp drops below this value  self power off occurs!
PowerOnTemp      = 140   ' after the average exhaust temp reaches this value the power off temp is monitored

SERVOMODE()
LCD.INIT
Light=off       ' off means display light is on because digital port is pulled to low !
LCD.POS 1,1
PRINT "Initialize"
MOVEPOSITION(0)      'fully open secondary air intake


'-------------------------------------------------
'--             Measuring cycle                  -
'------------------------------------------------- 
#LOOP

IF TSet = OFF THEN
  SETUPMENU(20)
END IF

  
IF LamdaVoltage > ReferenceVoltage + Tolerance THEN 'too much oxigen
  IF Position + 10 <= MaxPosition THEN              ' the intake is not fully closed yet
    MOVEPOSITION(Position + 10)                     ' close secondary air intake a bit more
  END IF     
END IF

IF LamdaVoltage < ReferenceVoltage - Tolerance THEN 'not enough oxigen
  IF Position - 10 >= 0 THEN                        ' the intake is not fully openend
    MOVEPOSITION(Position - 10)                     ' open secondary air intake a bit more   
  END IF  
END IF


READVALUEI2C() 
ExhaustTemp =  Temperatur/64 - 32  ' Formula for Temp Module R3 (-32°C / + 480°C)
IF ExhaustTemp > 1 THEN            ' Prevent AverageTemp from sudden drops (could be caused by IIC Read errors)
  AverageTemp = (AverageTemp + ExhaustTemp) / 2
END IF
   
IF NOT Operation AND AverageTemp > PowerOnTemp THEN  ' Once an AverageTemp of PowerOnTemp °C has been reached the oven is operating
  Operation = TRUE
END IF

'-------------------------------------------------
'--   self shutdown if exhaust temp is low       -
'------------------------------------------------- 
IF Operation AND AverageTemp < PowerOffTemp  THEN
  Power=off
END IF
  
LCD.POS 1,1
'PRINT ((LamdaVoltage * 196) / 10000) & "," &  ((LamdaVoltage * 196) mod 10000) & " V        " 
PRINT "Pos " & Position  & " AD1 " & LamdaVoltage  & "              "
LCD.POS 2,1
PRINT "T " &  ExhaustTemp & " AT "  & AverageTemp & "               "

PAUSE 250  ' wait approx 2,5 seconds bevor measuring again, because oxigen levels don't change very fast

GOTO LOOP



'-------------------------------------------------
'--        SERVO MODE AKTIVIEREN                -
'-------------------------------------------------
FUNCTION SERVOMODE()
CONFIG.INIT
CONFIG.PUT 00000001b
CONFIG.OFF
END FUNCTION


'-------------------------------------------------
'-         FUNCTION READVALUEI2C                 -
'-------------------------------------------------
FUNCTION READVALUEI2C()
' Read values from temperature sensor via IIC bus
' The display needs to be deactivated first

LCD.OFF
WITH IIC 
  .INIT 
  .START
  .SEND F1h  
  .GET TemperaturMSB 
  .GET TemperaturLSB 
  .STOP 
  .OFF
END WITH
LCD.INIT
END FUNCTION

'-------------------------------------------------
'-         FUNCTION MOVEPOSITION                 -
'-------------------------------------------------
FUNCTION MOVEPOSITION(NewPosition AS BYTE)

Serv1=NewPosition    'output servo position on DA1
PAUSE 20  

IF Position > NewPosition THEN
  Serv1=NewPosition + 1  'relax servo a little bit     
END IF           
IF Position < NewPosition THEN
  Serv1=NewPosition - 1  'relax servo a little bit  
END IF
   
Position = NewPosition
  
END FUNCTION

'-------------------------------------------------
'-         FUNCTION SETUPMENU                    -
'-------------------------------------------------
FUNCTION SETUPMENU(Iterations AS BYTE)

LCD.Clear
 
#SETUPLOOP

LCD.POS 1,1
PRINT "Setup " &Iterations 

' if the red button is pressed the MenuItem and the Iterations countdown counter is increased  
IF TSet=off THEN
  MenuItem = MenuItem + 1
  Iterations = Iterations + 1
END IF

' the MenuItem jumps back to the first item after the last one has been reached
IF MenuItem > 5 THEN
  MenuItem = 1
END IF

LCD.POS 2,1

Select Case MenuItem 
   Case 1 
      PRINT "PowerOffTemp " &  PowerOffTemp
      
      IF TUp = off THEN
        PowerOffTemp = PowerOffTemp + 5
        Iterations = Iterations + 1
      END IF
      IF TDown = off THEN
        PowerOffTemp = PowerOffTemp - 5
        Iterations = Iterations + 1
      END IF
      
   Case 2 
      PRINT "Reference " &  ReferenceVoltage
      
      IF TUp = off THEN
        ReferenceVoltage = ReferenceVoltage + 5
        Iterations = Iterations + 1
      END IF
      IF TDown = off THEN
        ReferenceVoltage = ReferenceVoltage - 5
        Iterations = Iterations + 1
      END IF
   Case 3 
      PRINT "Tolerance " &  Tolerance
      
      IF TUp = off THEN
        Tolerance = Tolerance + 1
        Iterations = Iterations + 1
      END IF
      IF TDown = off THEN
        Tolerance = Tolerance - 1
        Iterations = Iterations + 1
      END IF
   Case 4 
      PRINT "MaxPosition " &  MaxPosition
      
      IF TUp = off THEN
        MaxPosition = MaxPosition + 10
        Iterations = Iterations + 1
      END IF
      IF TDown =off THEN
        MaxPosition = MaxPosition - 10
        Iterations = Iterations + 1
      END IF    
   Case 5
      PRINT "PowerOnTemp " &  PowerOnTemp

      IF TUp = off THEN
        PowerOnTemp = PowerOnTemp + 5
        Iterations = Iterations + 1
      END IF
      IF TDown =off THEN
        PowerOnTemp = PowerOnTemp - 5
        Iterations = Iterations + 1
      END IF

End Select

' wait 1/2 second and count down Iterations until the menu time is up
IF Iterations > 1 THEN

  Iterations = Iterations - 1
  PAUSE 50
  LCD.Clear
  GOTO SETUPLOOP
END IF
  
END FUNCTION
