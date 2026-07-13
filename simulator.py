import time
import psycopg2
import pandas as pd
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()  # reads the .env file into environment variables

DB_CONFIG = {
    "dbname": os.environ.get("DB_NAME"),
    "user": os.environ.get("DB_USER"),
    "password": os.environ.get("DB_PASSWORD"),
    "host": os.environ.get("DB_HOST"),
    "port": os.environ.get("DB_PORT")
}

# 2. FILE PATH
CSV_FILE_PATH = os.environ.get("CSV_FILE_PATH")

def run_transaction_simulator():
    print("STARTING: Initializing Live Credit Card Transaction Simulator...")
    
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("SUCCESS: Connected to PostgreSQL.")
    except Exception as e:
        print(f"ERROR: Connection failed: {e}")
        return

    try:
        # Load the first 50 rows to test our system
        df = pd.read_csv(CSV_FILE_PATH, nrows=50)
    except Exception as e:
        print(f"ERROR: Could not read CSV: {e}")
        return

    print("\nSTREAM STARTED: Monitoring incoming transactions...\n")
    
    # 3. CORE LOGIC LOOP
    for index, row in df.iterrows():
        trans_id = int(row['Unnamed: 0'])
        cc_num = int(row['cc_num'])
        merchant = str(row['merchant'])
        amt = float(row['amt'])
        trans_num = str(row['trans_num'])
        current_timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Insert data into PostgreSQL
        insert_query = """
        INSERT INTO transactions (trans_id, trans_num, trans_date_time, cc_num, merchant_name, amt)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (trans_id) DO NOTHING;
        """
        
        try:
            cursor.execute(insert_query, (trans_id, trans_num, current_timestamp, cc_num, merchant, amt))
            conn.commit()
            
            # Standard print log for every transaction
            print(f"[PROCESSING] Card: ...{str(cc_num)[-4:]} | Merchant: {merchant[:20]} | Amt: ${amt:<7}")
            
            # --- SIMPLE PYTHON ALERT LOGIC ---
            # If a transaction is over $500, trigger an immediate alert simulation
            if amt > 500.00:
                print(f"   🚨 ALERT: High-Value Transaction Detected! Card ...{str(cc_num)[-4:]} spent ${amt} at {merchant[:20]}. Sending verification request to user...")
            # ----------------------------------
            
        except Exception as e:
            conn.rollback()
            print(f"WARNING: Error inserting row: {e}")

        # Pause for 2 seconds before the next swipe
        time.sleep(2)

    cursor.close()
    conn.close()
    print("\nFINISH: Simulation complete.")

if __name__ == "__main__":
    run_transaction_simulator()