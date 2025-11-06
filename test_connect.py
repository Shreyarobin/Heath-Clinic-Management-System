import mysql.connector
import config  # uses your real credentials

try:
  conn = mysql.connector.connect(
      host=config.HOST,
      user=config.USER,
      password=config.PASSWORD,
      database=config.DATABASE,
      port=getattr(config, "PORT", 3306)
  )
  cur = conn.cursor()
  cur.execute("SELECT DATABASE(), VERSION()")
  db, ver = cur.fetchone()
  print("Connected!")
  print("Database:", db)
  print("MySQL version:", ver)
except mysql.connector.Error as e:
  print("Connection failed:", e)
finally:
  try:
    cur.close()
    conn.close()
  except:
    pass
