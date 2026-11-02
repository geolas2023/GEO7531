# GEO7531
Codes et exemples du cours GEO7531
Importation d'un fichir .backup

Un fichier .backup est généralement une sauvegarde PostgreSQL créée avec pg_dump. Contrairement à un fichier .sql, il s'importe normalement avec la fonction Restore de pgAdmin.

Étape 1:
<img width="803" height="563" alt="image" src="https://github.com/user-attachments/assets/ddd57b57-7092-42e7-9216-8f32a9d761b7" />

1-Ouvre pgAdmin 4.
2-Dans le panneau de gauche, développe Servers, puis ton serveur PostgreSQL.
3-Fais un clic droit sur Databases.
4-Sélectionne Create → Database.
5-Donne un nom à ta base, par exemple GEO7531.
6-Clique sur Save.

Étape 2:
<img width="1352" height="713" alt="image" src="https://github.com/user-attachments/assets/05cbbf7e-4a52-4efe-8bb2-1f605302176d" />
1-Fais un clic droit sur la nouvelle base ma_base_SIG.
2-Sélectionne Restore.
3-Dans la fenêtre, sélectionne le format Custom or tar (ou laisse Format sur Auto selon ta version).
4-Dans Filename, sélectionne ton fichier .backup.
5-Dans les options de restauration, active No owner et No privileges si la sauvegarde provient d'un autre ordinateur ou utilisateur.
6-Clique sur Restore.
