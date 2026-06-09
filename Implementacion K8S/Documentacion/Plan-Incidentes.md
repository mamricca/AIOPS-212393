# Plan de Mitigación de Incidentes Operacionales

## 1. Introducción
### 1.1 Propósito
Este documento define el proceso de gestión de incidentes operacionales para los servicios críticos de la plataforma, estableciendo procedimientos para detección, análisis, contención, mitigación, recuperación y cierre de incidentes.

El objetivo del plan es minimizar el impacto sobre la disponibilidad y confiabilidad de los servicios mediante una respuesta coordinada, procedimientos estandarizados y mecanismos de observabilidad y recuperación.

Además, el documento establece lineamientos para escalamiento, comunicación, documentación y análisis post-incidente, promoviendo una cultura de mejora continua y postmortems blameless.
### 1.2 Alcance
El presente plan aplica a la gestión de incidentes operacionales que afecten la disponibilidad, estabilidad, rendimiento o confiabilidad de los servicios críticos de la plataforma.

El alcance incluye incidentes relacionados con infraestructura, microservicios, despliegues, monitoreo, observabilidad, redes, almacenamiento y componentes ejecutados sobre el entorno Kubernetes. Asimismo, contempla incidentes provocados por degradación de recursos, errores de configuración, fallos de despliegue y escenarios simulados mediante prácticas de chaos engineering.

Este documento define procedimientos de detección, escalamiento, contención, mitigación, recuperación y análisis post-incidente para eventos que impacten la operación normal de la plataforma.
### 1.3 Principios de Gestión de Incidentes
La gestión de incidentes operacionales se basa en principios orientados a minimizar el impacto sobre la disponibilidad y confiabilidad de los servicios, priorizando la restauración rápida de la operación normal por encima de soluciones definitivas inmediatas.

Todos los incidentes deberán gestionarse mediante procedimientos estandarizados de detección, escalamiento, mitigación y recuperación, promoviendo una respuesta coordinada entre los distintos roles operacionales.

Las decisiones técnicas y operacionales deberán sustentarse en información verificable proveniente de métricas, logs, alertas y herramientas de observabilidad, evitando acciones no validadas durante escenarios críticos.

La escalada temprana de incidentes críticos será considerada prioritaria para reducir el tiempo de recuperación y limitar la propagación del impacto sobre otros servicios dependientes.

Los procesos de análisis post-incidente deberán realizarse bajo una política de blameless postmortem, enfocándose en identificar causas raíz, oportunidades de mejora y medidas preventivas, evitando la asignación individual de culpabilidad.
### 1.4 Definiciones y Terminología
| Término | Definición |
|---|---|
| Incidente | Evento que afecta o puede afectar la disponibilidad, estabilidad, rendimiento o confiabilidad de uno o más servicios de la plataforma. |
| Severidad | Nivel de impacto asignado a un incidente en función de su alcance, criticidad y efecto sobre la operación. |
| Escalamiento | Proceso de involucrar recursos técnicos, operacionales o de gestión adicionales para responder a un incidente. |
| Mitigación | Conjunto de acciones orientadas a reducir el impacto inmediato de un incidente sin necesariamente resolver su causa raíz. |
| Recuperación | Proceso de restaurar los servicios afectados a un estado operativo estable y validado. |
| Runbook | Documento técnico con procedimientos específicos para responder a incidentes o ejecutar tareas operacionales repetitivas. |
| Postmortem | Análisis realizado luego de un incidente con el objetivo de identificar causas raíz, impacto, acciones correctivas y oportunidades de mejora. |
| RCA (Root Cause Analysis) | Proceso de análisis orientado a identificar la causa raíz de un incidente. |
| MTTD | Mean Time To Detect. Tiempo promedio requerido para detectar un incidente. |
| MTTRepair | Mean Time To Repair. Métrica interna utilizada para medir el tiempo promedio requerido para identificar y corregir la causa técnica de un incidente. |
| MTTRestore | Mean Time To Restore. Métrica utilizada para medir el tiempo promedio requerido para restaurar la operación normal de los servicios afectados luego de un incidente. |
## 2. Descripción General de la Arquitectura
### 2.1 Descripción del Sistema
La plataforma está compuesta por una aplicación web, servicios backend desacoplados, una base de datos y componentes de observabilidad desplegados sobre Kubernetes. Su operación depende del correcto funcionamiento de los pods, servicios, volúmenes persistentes, configuración de red y del stack de monitoreo.

Durante un incidente, esta sección sirve como referencia rápida para identificar qué componente puede estar afectado y cómo se relaciona con el resto del entorno.
### 2.2 Servicios Críticos
Los servicios críticos son la API, el gateway, la base de datos y los componentes de autenticación o catálogo que impactan directamente la operación de la plataforma.
### 2.3 Dependencias de Infraestructura
El sistema depende del clúster Kubernetes, los namespaces, los servicios internos, los volúmenes persistentes, las configuraciones y los secretos necesarios para ejecutar cada componente.
### 2.4 Stack de Monitoreo y Observabilidad
La observabilidad se apoya en métricas, logs y trazas para detectar degradaciones, validar alertas y confirmar si la causa del incidente está en aplicación, infraestructura o red.

## 3. Roles y Responsabilidades
### 3.1 Incident Commander
Responsable de coordinar la respuesta al incidente, asignar prioridades, organizar el war room y supervisar el avance de las tareas de mitigación y recuperación. Actúa como principal punto de decisión durante incidentes críticos.
### 3.2 Líder Técnico
Responsable de liderar el análisis técnico del incidente, identificar posibles causas raíz y coordinar las acciones necesarias para contener y restaurar los servicios afectados.
### 3.3 Responsable de Comunicaciones
Encargado de mantener informados a los equipos involucrados y stakeholders mediante actualizaciones periódicas sobre el estado del incidente, impacto identificado y progreso de recuperación.
### 3.4 Equipo SRE / DevOps
Responsable de ejecutar procedimientos operacionales, aplicar mitigaciones, realizar despliegues, rollbacks, escalamiento de servicios y validar la estabilidad de la plataforma durante y después del incidente.
### 3.5 Stakeholders y Roles de Escalamiento
Los stakeholders operacionales y técnicos podrán ser incorporados durante incidentes de alta severidad cuando el impacto afecte servicios críticos, disponibilidad de la plataforma o tiempos de recuperación esperados.
## 4. Clasificación de Incidentes
### 4.1 Niveles de Severidad
La severidad de un incidente será determinada en función del impacto operacional observado sobre la disponibilidad, estabilidad y funcionamiento de los servicios críticos de la plataforma. La clasificación inicial podrá ser actualizada durante el ciclo de vida del incidente si el alcance o impacto cambian.

El nivel de severidad asignado determinará la prioridad operativa, los mecanismos de escalamiento y el nivel de coordinación requerido para la respuesta al incidente.
| Severidad | Descripción | Impacto Operacional |
|---|---|---|
| Sev1 | Interrupción total o degradación crítica de servicios esenciales. | La plataforma o funcionalidades críticas se encuentran indisponibles para la mayoría de los usuarios. Requiere respuesta inmediata y coordinación mediante war room. |
| Sev2 | Degradación significativa de uno o más servicios críticos. | Existe impacto operativo importante, aunque el sistema continúa parcialmente funcional. Requiere escalamiento técnico prioritario. |
| Sev3 | Incidente de impacto moderado o limitado. | El incidente afecta funcionalidades específicas sin comprometer completamente la operación general de la plataforma. |
| Sev4 | Incidente menor o anomalía sin impacto crítico inmediato. | El problema no afecta significativamente la disponibilidad ni la operación principal de los servicios. |
### 4.2 Criterios de Escalamiento
Los incidentes deberán escalarse en función de su severidad, impacto operacional, tiempo estimado de recuperación y riesgo de propagación hacia otros servicios dependientes.

Los incidentes clasificados como Sev1 requerirán escalamiento inmediato, activación de war room y coordinación continua entre los equipos involucrados hasta la restauración del servicio.

Los incidentes Sev2 deberán escalarse prioritariamente cuando exista degradación significativa, riesgo de interrupción total o dependencia directa de servicios críticos afectados.

Asimismo, cualquier incidente podrá ser escalado independientemente de su severidad inicial cuando no exista diagnóstico claro, el impacto aumente progresivamente o los tiempos esperados de recuperación superen los límites operacionales definidos.
## 5. Ciclo de Vida del Incidente
### 5.1 Detección
La detección de incidentes podrá originarse mediante alertas automáticas, degradación observada en métricas, logs, trazas distribuidas, herramientas de monitoreo o reportes de usuarios. Todo incidente detectado deberá validarse antes de iniciar procedimientos de escalamiento y respuesta.
### 5.2 Registro del Incidente
Una vez confirmado el incidente, deberá registrarse información relevante sobre servicios afectados, hora de detección, impacto observado, severidad inicial y responsables asignados para su seguimiento.
### 5.3 Evaluación Inicial
La evaluación inicial tendrá como objetivo determinar el alcance operacional del incidente, identificar servicios críticos afectados y asignar el nivel de severidad correspondiente para coordinar la respuesta adecuada.
### 5.4 Escalamiento
El incidente deberá escalarse según criterios de severidad, impacto, tiempo estimado de recuperación y riesgo de propagación hacia otros componentes dependientes de la plataforma.
### 5.5 Contención
Las acciones de contención tendrán como objetivo limitar la propagación del incidente y reducir el impacto sobre los servicios críticos mediante aislamiento de componentes, restricciones operacionales o mitigaciones temporales.
### 5.6 Mitigación
La mitigación incluirá procedimientos destinados a estabilizar el entorno afectado y restaurar parcialmente la operación mientras se continúa el análisis técnico de la causa raíz.
### 5.7 Recuperación
La fase de recuperación tendrá como objetivo restaurar la operación normal de los servicios afectados, validando estabilidad, disponibilidad y funcionamiento esperado antes de finalizar el incidente.
### 5.8 Resolución
La resolución del incidente se realizará una vez identificada y corregida la causa raíz o cuando el riesgo operacional residual sea considerado aceptable para la continuidad del servicio.
### 5.9 Cierre del Incidente
Finalizada la recuperación, el incidente deberá documentarse formalmente incluyendo timeline, impacto, acciones ejecutadas, causa raíz identificada y medidas preventivas definidas para evitar recurrencias futuras.

## 6. Detección y Monitoreo
### 6.1 Fuentes de Monitoreo
Las principales fuentes de monitoreo son las métricas del clúster y de las aplicaciones, los logs centralizados y las alertas generadas por el stack de observabilidad. Estas señales permiten detectar comportamiento anómalo y ubicar rápidamente el componente afectado.
### 6.2 Métricas y Alertas
Las métricas y alertas se utilizan para identificar degradaciones de CPU, memoria, latencia, disponibilidad y errores. En un incidente, sirven como primera evidencia para confirmar impacto y severidad.
### 6.3 Centralización de Logs
La centralización de logs permite revisar eventos del sistema, errores de aplicación y mensajes de infraestructura desde un único punto. Esto facilita correlacionar síntomas y acotar la causa del problema.
### 6.4 Trazabilidad Distribuida
La trazabilidad distribuida ayuda a seguir el recorrido de una solicitud entre servicios y detectar dónde se produce la falla o el aumento de latencia. Es especialmente útil en incidentes que involucran varios microservicios.
### 6.5 Validación de Alertas
Toda alerta debe validarse antes de escalar el incidente para confirmar que corresponde a un evento real y no a un falso positivo. La validación inicial debe cruzar métricas, logs y estado de los componentes afectados.

## 7. Procedimientos de Respuesta a Incidentes
Los siguientes flujos definen los procedimientos operacionales de respuesta ante incidentes según el nivel de severidad asignado. Cada flujo establece las acciones mínimas esperadas para coordinación, escalamiento, mitigación y recuperación durante el ciclo de vida del incidente.

La respuesta operacional deberá priorizar la restauración rápida de los servicios afectados, la reducción del impacto sobre la plataforma y la comunicación continua entre los equipos involucrados.
### 7.1 Flujo de Respuesta Sev1
- Confirmar incidente y validar impacto.
- Clasificar severidad como Sev1.
- Activar war room inmediatamente.
- Asignar Incident Commander.
- Escalar equipos técnicos necesarios.
- Priorizar contención y restauración del servicio.
- Comunicar estado periódicamente.
- Validar estabilidad post-recuperación.
- Registrar timeline y preparar postmortem.
### 7.2 Flujo de Respuesta Sev2
- Confirmar degradación operacional.
- Asignar severidad Sev2.
- Escalar equipos técnicos prioritarios.
- Aplicar mitigaciones preventivas.
- Monitorear impacto y riesgo de propagación.
- Validar recuperación y estabilidad.
- Registrar acciones ejecutadas.
### 7.3 Flujo de Respuesta Sev3
- Registrar incidente.
- Validar impacto limitado.
- Asignar responsables técnicos.
- Aplicar procedimientos estándar.
- Monitorear evolución del incidente.
- Escalar si el impacto aumenta.
### 7.4 Flujo de Respuesta Sev4
- Registrar anomalía o incidente menor.
- Programar seguimiento operativo.
- Validar ausencia de impacto crítico.
- Resolver mediante mantenimiento estándar.
### 7.5 Comunicación Durante Incidentes
Toda actualización relevante sobre el incidente deberá comunicarse oportunamente a los equipos involucrados y stakeholders correspondientes, incluyendo cambios de severidad, impacto identificado, mitigaciones aplicadas y estado de recuperación.
### 7.6 Coordinación de War Room
La activación de war room se realizará ante incidentes críticos o escenarios de alta incertidumbre operacional. El war room funcionará como espacio centralizado de coordinación técnica, seguimiento de acciones y toma de decisiones durante el incidente.
### 7.7 Procedimientos de Escalamiento
Los procedimientos de escalamiento deberán activarse cuando el impacto operacional aumente, no exista diagnóstico claro, los tiempos de recuperación excedan lo esperado o exista riesgo de propagación hacia otros servicios críticos.

## 8. Estrategias de Contención y Mitigación
Las estrategias definidas en esta sección se alinean con las fases del framework de Atlassian y buscan reducir el impacto inmediato del incidente, estabilizar la operación y evitar recurrencias. Su aplicación debe ser proporcional a la severidad del evento y a la criticidad del componente afectado.

En este sistema, las medidas de contención y mitigación deben considerar el comportamiento del API Gateway, los microservicios de usuarios y farmacia, la base de datos compartida y los componentes de observabilidad y logging desplegados sobre Kubernetes.

### 8.1 Aislamiento de Servicios
El aislamiento de servicios consiste en limitar la interacción del componente afectado con el resto de la plataforma para evitar la propagación del impacto. Esta medida puede incluir la exclusión temporal de réplicas inestables, la desactivación de una ruta del gateway o la separación de un microservicio con comportamiento anómalo.

Esta estrategia se utiliza durante las fases de análisis y contención, cuando todavía se busca mantener operativa la mayor parte del sistema mientras se identifica el origen del problema.

### 8.2 Procedimientos de Rollback
Los procedimientos de rollback permiten revertir un despliegue, una configuración o un cambio reciente que haya introducido la falla. Su aplicación debe priorizar versiones previamente validadas para volver rápidamente a un estado operativo estable.

Esta medida se emplea cuando el incidente está asociado a una modificación reciente y se necesita erradicar el cambio defectuoso como parte de la mitigación y la recuperación.

### 8.3 Limitación de Tráfico
La limitación de tráfico busca reducir la presión sobre los servicios afectados mediante rate limiting, control de solicitudes simultáneas o filtrado temporal de consumo. Esto ayuda a evitar una degradación adicional mientras se ejecutan las acciones de análisis y estabilización.

En incidentes de alta carga, esta estrategia permite sostener la disponibilidad del sistema y ganar tiempo para corregir la causa técnica sin agravar el impacto operativo.

### 8.4 Escalamiento Horizontal
El escalamiento horizontal consiste en aumentar el número de réplicas de un servicio para absorber mayor carga o compensar degradaciones parciales. Debe aplicarse cuando el incidente está relacionado con saturación de recursos, picos de tráfico o pérdida de capacidad de procesamiento.

Esta acción forma parte de la mitigación y recuperación, ya que permite restaurar capacidad operativa mientras se investiga y corrige la causa raíz.

### 8.5 Failover y Recuperación
El failover consiste en redirigir la operación hacia una instancia, nodo o componente alternativo cuando el principal deja de ser confiable o disponible. En este entorno, esta estrategia es útil ante fallos de base de datos, pérdida de un pod crítico o degradación de infraestructura subyacente.

Su objetivo es sostener la continuidad del servicio durante la recuperación y evitar que el impacto se extienda a otros componentes dependientes.

### 8.6 Auto-Recovery en Kubernetes
Los mecanismos de auto-recovery en Kubernetes incluyen reinicio automático de pods, recreación de réplicas fallidas, health checks y reprogramación de cargas ante errores de infraestructura o aplicación. Estos comportamientos permiten recuperar servicios de forma automática cuando la falla es transitoria o está contenida.

Estas capacidades deben complementarse con supervisión activa para confirmar que la auto-recuperación fue efectiva y que el incidente no reaparece por una causa estructural.

## 9. Plan de Comunicación Operacional
### 9.1 Comunicación Interna
La comunicación interna deberá realizarse a través de los canales operacionales definidos para la gestión de incidentes. Toda actualización relevante deberá compartirse con los equipos involucrados para asegurar una visión común de la situación y coordinar las acciones de respuesta.
### 9.2 Comunicación con Stakeholders
Los stakeholders deberán recibir actualizaciones acordes al nivel de impacto del incidente, incluyendo servicios afectados, severidad asignada, acciones de mitigación en curso y tiempos estimados de recuperación cuando estén disponibles.
### 9.3 Actualizaciones de Estado
Durante incidentes activos se deberán emitir actualizaciones periódicas que reflejen el estado actual de la situación, cambios de severidad, mitigaciones aplicadas y progreso de recuperación. La frecuencia de comunicación dependerá del nivel de criticidad del incidente.
| Severidad | Frecuencia de Actualización |
|---|---|
| Sev1 | Cada 15-30 minutos o ante cambios significativos. |
| Sev2 | Cada 30-60 minutos o ante cambios relevantes. |
| Sev3 | Según sea necesario o ante cambios relevantes. |
| Sev4 | Al cierre del incidente. |
### 9.4 Comunicación Externa
Cuando el incidente impacte servicios visibles para usuarios finales, podrá emitirse comunicación externa mediante los canales definidos por la organización, informando el estado del servicio y las acciones de recuperación en curso. Esta comunicación deberá ser coordinada con el equipo de comunicaciones y alineada con la política de transparencia y manejo de crisis de la empresa.
### 9.5 Gestión de Status Page
La página de estado deberá utilizarse como fuente oficial de información durante incidentes que afecten la disponibilidad de los servicios. Toda actualización publicada deberá reflejar información validada y consistente con el estado operativo real de la plataforma.

## 10. Runbooks Operacionales
### 10.1 Objetivo de los Runbooks

Los runbooks son guías operativas paso a paso diseñadas para reducir la incertidumbre durante un incidente y acelerar la respuesta. Su objetivo es:

- Proveer instrucciones reproducibles y verificables para contención, mitigación y recuperación.
- Reducir el tiempo de decisión en situaciones de presión (MTTR/MTTD).
- Normalizar acciones entre equipos y facilitar la transferencia de contexto.

Un runbook bien diseñado permite a un operador seguir un flujo claro (validación → contención → mitigación → recuperación → verificación) y registrar evidencia y resultados.

### 10.2 Estructura Estándar

Cada runbook debe respetar una plantilla mínima para ser eficaz y utilizable por cualquier miembro del equipo:

- Título: nombre claro y versionable.
- Alcance: qué cubre y qué no cubre el runbook.
- Criterios de activación: señales/alertas que disparan el uso del runbook.
- Precondiciones: permisos, accesos, datos necesarios y comprobaciones previas.
- Pasos de acción (ordenados y numerados): comandos concretos, endpoints, manifestos y comprobaciones posteriores a cada paso.
- Indicadores de éxito / criterios de salida: métricas o verificaciones para considerar el paso/fin completado.
- Rollback: pasos para revertir cambios aplicados por el runbook si fallan.
- Contactos: responsables, escalamiento y canales (Slack/Teams/email) con nombres y roles.
- Referencias y enlaces: dashboards (Grafana), búsquedas de logs (Kibana), traces (OTel), y tickets relacionados.
- Historial de cambios y autoría.

Ejemplo de plantilla rápida (al inicio del runbook):

- Nombre: "RB-01 Servicio No Disponible - UsersService"
- Versión: 2026-06-06
- Activación: alerta Grafana `pharmago_users_http_errors > 5%` durante 5min
- Objetivo: restaurar endpoints `/api/users/**` en < 30min

### 10.3 Criterios de Activación

Definir criterios claros evita falsas activaciones y orienta respuestas apropiadas. Los criterios deben ser cuantitativos siempre que sea posible:

- Alertas métricas: umbrales y duración (p.ej. latencia p95 > 1s por >5min, error rate > 5% 5min).
- Alertas de logs: patrones críticos (p.ej. excepciones repetidas, OOM, timeouts en DB).
- Señales de trazas: spans con errores en pasos críticos o aumento de latencia entre servicios.
- Señales operativas: despliegue fallido, replicas CrashLoopBackOff, PV con estado ReadOnly.

Procedimiento de validación previa a la activación:

1. Corroborar alerta en Grafana con métricas históricas.
2. Revisar logs en Kibana para el window temporal de la alerta.
3. Consultar trazas (si están disponibles) para identificar tramo problemático.
4. Si las tres fuentes coinciden, activar runbook y notificar Incident Commander.

### 10.4 Gestión y Versionado

Los runbooks deben tratarse como código: almacenados en repositorio, revisados y probados periódicamente.

- Ubicación: mantener runbooks en el repo bajo `Documentacion/runbooks/`.
- Control de cambios: cambios mediante PR con al menos una revisión técnica y una aprobación de SRE.
- Versionado: semantic tag o fecha en el encabezado del runbook; registrar pruebas de ejecución y resultados.
- Pruebas periódicas: ejecutar ejercicios de mesa (table-top) o simulaciones (chaos) para validar pasos críticos al menos semestralmente.
- Mantenimiento: asignar un responsable por runbook con cadencia de revisión (ej. trimestral).

### 10.5 Referencias a Runbooks Técnicos

Cada runbook operativo debe contener enlaces y referencias a runbooks técnicos detallados ubicados en la Sección 11 (Catálogo de Runbooks). Ejemplos de enlaces y recursos a incluir:

- Runbook técnico para "Alto Consumo de CPU" → `Documentacion/runbooks/alto-cpu.md`.
- Runbook técnico para "Falla de Base de Datos" → `Documentacion/runbooks/db-failure.md`.
- Comandos comunes: `kubectl` short-cmds, querys de Prometheus y ejemplos de búsqueda en Kibana.
- Dashboards relevantes: enlaces directos a los dashboards de Grafana pre-provisionados.
- Playbooks de rollback y scripts de emergencia guardados en `Codigo/ops-scripts/`.

Además, incluir una sección de "Lecciones aprendidas" en cada runbook para documentar mejoras surgidas tras su ejecución.

## 11. Catálogo de Runbooks
### 11.1 Alto Consumo de CPU
### 11.2 Memory Leak
### 11.3 Servicio No Disponible
### 11.4 Falla de Base de Datos
### 11.5 Degradación de Red
### 11.6 Despliegue Fallido
### 11.7 Ejecución de Rollback
### 11.8 Saturación de Recursos
### 11.9 Falla de Observabilidad
### 11.10 Recuperación de Pods


## 12. Proceso de Postmortem

### 12.1 Política de Blameless Postmortem

La política de postmortem es "blameless": el objetivo es aprender y mejorar, no asignar culpa. Todo postmortem debe centrarse en causas sistémicas y en acciones concretas de mitigación y prevención.

- Confidencialidad y respeto: mantener un tono constructivo en análisis y reportes.
- Transparencia: documentar hechos, timeline y evidencia verificable.
- Responsabilidad compartida: proponer responsables para acciones correctivas, no culpables personales.

### 12.2 Timeline del Incidente

Registrar una línea de tiempo precisa es esencial para entender el flujo del incidente. Debe incluir:

- Marca temporal de detección (MTTD) y de restauración (MTTR).
- Alertas y pantallazos relevantes (Grafana, Kibana, traces).
- Acciones realizadas (quién, cuándo, qué comandos/rollbacks se aplicaron).
- Cambios de severidad y comunicaciones a stakeholders.

Formato sugerido: tabla o lista ordenada con timestamps ISO y breve descripción por evento.

### 12.3 Análisis de Causa Raíz

El RCA debe describir la cadena causal que llevó al incidente, diferenciando entre causa inmediata, causas contribuyentes y causa raíz:

- Recolección de evidencia: métricas, logs, trazas, despliegues, config diffs.
- Hipótesis iniciales y pruebas realizadas para descartarlas o confirmarlas.
- Identificación de factores humanos, procesos y técnicos que permitieron la falla.
- Conclusión: causa raíz claramente enunciada y justificada.

### 12.4 Acciones Correctivas

Dividir las acciones en corto plazo (mitigación), mediano plazo (corrección) y largo plazo (prevención):

- Corto plazo: pasos para restaurar servicio y asegurar estabilidad inmediata (ej. rollback, escala horizontal temporal).
- Mediano plazo: correcciones de código/configuración, despliegues seguros, parches.
- Largo plazo: cambios en la arquitectura, mejoras en testing, automatización de recuperaciones.

Para cada acción indicar: descripción, responsable, fecha objetivo, criterio de cierre y riesgo residual.

### 12.5 Medidas Preventivas

Definir medidas concretas que reduzcan la probabilidad de recurrencia:

- Ajuste de alertas y umbrales (evitar ruido y mejorar MTTD).
- Añadir pruebas automatizadas (integración/chaos) enfocadas en la falla encontrada.
- Hardenización de despliegues: estrategias de rolling, health checks mejorados, replicas mínimas.
- Documentación y runbooks actualizados con pasos verificados.

Registrar el seguimiento de cada medida preventiva en el backlog de mantenimiento con prioridad y dueño.

### 12.6 Lecciones Aprendidas

Resumen conciso de aprendizajes operativos y técnicos. Debe incluir:

- Qué funcionó bien durante la respuesta.
- Qué no funcionó y por qué.
- Cambios inmediatos ya aplicados.
- Próximos hitos y responsables para seguimiento.

El postmortem final debe publicarse en el repositorio (`Documentacion/postmortems/`) y compartirse con los equipos relevantes. Agregar una entrada en el runbook correspondiente si aplica.
