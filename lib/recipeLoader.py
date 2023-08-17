import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import csv

# Initialize Firebase Admin SDK
cred = credentials.Certificate("C:\\Users\\morit\\Documents\\App\\recipes\\recipes-d6ce7-firebase-adminsdk-ck1x4-0704f76fe2.json")
firebase_admin.initialize_app(cred)

# # Connect to Firestore
db = firestore.client()

# Read data from CSV file
with open('C:\\Users\\morit\\Downloads\\Rezepte-Tabellenblatt1.csv', 'r', encoding="utf-8") as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        title = row['Title']
        keywords = row['Keywords']
        duration = int(row['Cooking Time'])

        ingredients = []
        for ingredient in row['Ingredients'].split(';'):
            if ingredient == '':
                continue

            ingredient = ingredient.replace('\n', '')
            # ingredient = ingredient.replace(' ', '')
            items = ingredient.split(',')
            ingredientType = items[0].strip()

            if len(items) > 1:
                ingredientAmount = float(items[1].replace(' ', ''))
                ingredientUnit = items[2].replace(' ', '')
                ingredients.append({'type':ingredientType, 'amount':ingredientAmount, 'unit':ingredientUnit})
            else:
                ingredients.append({'type':ingredientType})
            
        descriptionList = []
        for description in row['Description'].split(';'):
            if description == '':
                continue
            description = description.replace('\n', '').strip()
            descriptionList.append(description)

        # print(title)
        # print(keywords)
        # print(duration)
        # print(ingredients)
        # print(descriptionList)
        # Create a new document in the "Recipes" collection
        recipe_ref = db.collection('Recipes').document()
        recipe_ref.set({
            'title': title,
            'image': '',
            'keywords': keywords,
            'duration': duration,
            'description': descriptionList,
            'ingredients': ingredients
        })

print("Recipes added successfully")