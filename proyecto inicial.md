actua como un administrador de base de datos proyecto: abarrotes que entidades se necesitan para su gestión
<img width="786" height="739" alt="image" src="https://github.com/user-attachments/assets/c0399e71-e1f2-4698-aeb1-59cf33ed7573" />
Entidades principales — descripción DBA
Gestión de usuarios y acceso
USUARIO es la entidad raíz: almacena credenciales y datos de cuenta. Un usuario puede tener múltiples PERFILes (como en Netflix real, hasta 5), y cada perfil tiene su propia actividad independiente. Los DISPOSITIVOs registrados permiten controlar sesiones activas y límites por plan.
Monetización
PLAN define los tiers de suscripción (Básico, Estándar, Premium) con sus restricciones de pantallas, calidad y descargas. SUSCRIPCION vincula usuario con plan, gestionando fechas de vigencia, estado y método de pago.
Catálogo de contenido
CONTENIDO es el núcleo del catálogo, abarcando películas y series. Las series se descomponen en TEMPORADA → EPISODIO. Los géneros se manejan con la tabla intermedia CONTENIDO_GENERO para una relación N:M limpia.
Actividad y engagement
VISUALIZACION registra el progreso por perfil y episodio, lo que permite reanudar donde se dejó. LISTA_FAVORITOS y CALIFICACION capturan las preferencias del usuario, alimentando el motor de recomendaciones.

Decisiones de diseño destacadas:

Se usa uuid como PK en todas las entidades para escalar en arquitecturas distribuidas.
VISUALIZACION guarda progreso_seg en segundos para precisión submillar.
PERFIL.es_infantil controla el filtro de contenido para perfiles kids.
EPISODIO.url_video puede apuntar a un CDN; en producción se añadiría una entidad ARCHIVO_VIDEO para gestionar resoluciones múltiples.

las entidades con sus atributos y tipo de forma de tabla para cada una de las entidades
<img width="747" height="355" alt="image" src="https://github.com/user-attachments/assets/d244742a-3b93-4c14-8379-cb393f284794" />
<img width="742" height="312" alt="image" src="https://github.com/user-attachments/assets/ae5f0c75-baac-40b2-8a2d-593e5c6001af" />
<img width="737" height="284" alt="image" src="https://github.com/user-attachments/assets/914a7ce8-0f89-4867-b8f8-52e13d40f988" />
<img width="750" height="338" alt="image" src="https://github.com/user-attachments/assets/3332bf00-13be-4bf2-b8c8-881337797608" />
<img width="738" height="311" alt="image" src="https://github.com/user-attachments/assets/ba38a49e-b14d-4662-9a59-645b3d91e33d" />
<img width="746" height="407" alt="image" src="https://github.com/user-attachments/assets/64841bfc-35d6-49db-bc6f-8ff28828a085" />
<img width="734" height="260" alt="image" src="https://github.com/user-attachments/assets/0983a41f-7868-4756-a354-4abf7bbb10da" />
<img width="747" height="342" alt="image" src="https://github.com/user-attachments/assets/ad792a0b-0ac4-4c3a-82bc-b154239c92a5" />
<img width="734" height="176" alt="image" src="https://github.com/user-attachments/assets/f0afecd1-500a-4b5d-8429-937f297f33a7" />
<img width="760" height="155" alt="image" src="https://github.com/user-attachments/assets/15ff9299-69a2-4563-85a9-0a6df407a3b0" />
<img width="751" height="285" alt="image" src="https://github.com/user-attachments/assets/0d2b597b-47e3-44d4-a215-7ecddab5aaee" />
<img width="743" height="227" alt="image" src="https://github.com/user-attachments/assets/f334ec22-6d5b-499f-8c47-b0433018831c" />
<img width="753" height="265" alt="image" src="https://github.com/user-attachments/assets/99a59824-fd9a-470d-82bd-c580e3a23f75" />

