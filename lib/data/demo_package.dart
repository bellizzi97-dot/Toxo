import 'knowledge_package.dart';

const demoKnowledgePackage = KnowledgePackage(
  packageId: 'toxo-demo-es-v1',
  sourceTitle: 'Biblioteca de demostración de Toxo',
  license: 'CC0-1.0',
  attribution: 'Contenido original de demostración creado para Toxo',
  sourceUrl: 'https://github.com/bellizzi97-dot/Toxo',
  articles: [
    KnowledgeArticle(
      id: 'toxo-demo-fotosintesis',
      title: 'Fotosíntesis',
      text:
          'La fotosíntesis es el proceso por el que plantas, algas y algunas bacterias convierten luz solar, agua y dióxido de carbono en azúcares. En las plantas ocurre principalmente en las hojas, dentro de estructuras llamadas cloroplastos, que contienen clorofila. Como resultado también se libera oxígeno. La energía queda almacenada en las moléculas de azúcar y sostiene gran parte de las cadenas alimentarias.',
    ),
    KnowledgeArticle(
      id: 'toxo-demo-volcanes',
      title: 'Volcanes',
      text:
          'Un volcán es una abertura de la corteza terrestre por la que pueden salir magma, gases y fragmentos de roca. Cuando el magma alcanza la superficie se llama lava. Los volcanes pueden formarse en límites de placas tectónicas y en puntos calientes. Su actividad puede crear nuevas rocas y suelos, aunque las erupciones también pueden representar riesgos para las comunidades cercanas.',
    ),
    KnowledgeArticle(
      id: 'toxo-demo-sistema-solar',
      title: 'Sistema solar',
      text:
          'El sistema solar está formado por el Sol y los objetos que permanecen ligados a su gravedad, entre ellos ocho planetas, sus lunas, planetas enanos, asteroides y cometas. Los planetas interiores Mercurio, Venus, la Tierra y Marte son rocosos. Júpiter y Saturno son gigantes gaseosos; Urano y Neptuno son gigantes helados. La Tierra completa una órbita alrededor del Sol aproximadamente cada 365 días.',
    ),
  ],
);
