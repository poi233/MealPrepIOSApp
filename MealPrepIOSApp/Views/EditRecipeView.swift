//
//  EditRecipeView.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct EditRecipeView: View {
    @EnvironmentObject
    @Environment(\.dismiss) private var dismiss
    
    Recipe
    
    // Recipe form data
    @State private var name: String
    @State private var description: String
    @State private var instructions
    @State private var cuisine: String
    @State private var prepTime: Int
    @State private var cookTime: Int
    @State private var difficulty: Dty
    @State private var imageUrl:
    @State private var tags: String
    @State private var ingredients: [IngredientInput]
    
    
    @State private var isUpdating = false
    ng?
    
    init(recipe: Recipe)
        self.recipipe
        
        // Initialize state variables with recipe data
        _name = State(initialValue: recipe.name)
        _description = State(initialValuen)
        _instructionctions)
        _cuisine = State(ini")
        _prepTime = State(initialValue:Time)
        _cookTime = State(initia)
        _difficulty = State(initialValue: recipe.difficulty)
        _imageUrl = State(initialValue: recipe.imageUrl ?? "")
        _tags = State
        
        // Conveput
        let ingredientInputs = recipe.ingredient
            IngredientInput(
                name: ingredient.name,
                amount: ingredie
                unit: ingredient.unit,
                notes
            )
        }
        _ingredients = State(initialValue)
        
        // Convert nutrition info to NutritionInput
        let nutritiono
        _nutritionInnput(
            calories: nutrition?.calories ?? "",
            protein: nutrition?.protein ?? "",
            carbohydrates: nutrition?.carbohydrates ?? "",
            fat: nutritio
            fiber: nu",
            sodiu
            suga",
            servings: nutrition?.serving? 0
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Secti {
                    name)
                    TextField("Description", t)
                        .lineLimit(3...6)
                    
                    HStack {
                 sine")
                Spacer()
                        TextField("e.g., 
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Timing & Difficulty") 
                    HStack {
                        Text("Prep Time")
                        Spacer()
                 
                
                    
                    HStack {
                 )
             )
                        Stepper("\(cookTime 5)
                    }
                    
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficin
                            Text(
                        }
                    }
                }
                
                Section("Ingredients") {
                    ForEach(ingredient
                     
                            if ingredients{
                                ingredients.remove(at: in)
                 }
             
                    }
                    
                    Button("Add ient") {
             )
         
     olor)
    
                
                Section("Instructions") {
                    TextField("Step-by-step instructions", text: $instructions,cal)
                        .lineLimit(5...15)
                }
         
    ails") {
                    TextField("Imagl)
                    TextFi$tags)
                        .textInputAutocaever)
                }
                
                Section("Nutrition) {
                    NutritionInfoVionInfo)
                }
                
                if let errorMessage = errorMessage {
        {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            )
                    }
                }
            }
            .navigationTitle("Edit Recipe")
            .e)
          {
        ading) {
                    Button("Cancel") {
                        dismiss(
                    }
             }
               
                ToolbarItem(placementing) {
                    Button("Save") {
                        updateRecipe()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isUpdating)
                }
            }
            .disabled(isUpdating)
        }
    }
    
    priva {
     
    
        !instructions.trimmingChapty &&
        ingredients.conta }
    }
    
    private func updateRecipe() {
        isUpdating = true
        errosage = nil
        
        let validIngredients = ing
            let trimmedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlin
            guard !trimmedName.isEmpty else { return nil }
            
            rient(
         e,
        nes),
                unit: ingredient.unit.trimmingCharacters
                notes: ingredient.notes?.trimmingCharacters(in: .whitesnes)
            )
        }
        
        let tagArray = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let nutrition = nutritionInfo.hasValues ? NutritionInfo(
            calories: nutritionInfo.calories.isEmpty ? nil : nutritionInfo.cal,
            protein: nutritionInfo.protein.isEmpty ? nil : nutritionInfo.protein,
            carbohydrates: nutritionInfo.carbohydrates.isEmpty ? nil : nutritioydrates,
            fatfo.fat,
        
            sodium: nutritionInfo.sodium.isEmptyodium,
            sugar: nutritionInfo.sugar.isEmpty ? nil : nutritionInfo.su,
            servings: nutritionInfo.servings > 0 ? nutritionInfo.servings : nil
        ) : nil
        
        let updatedRecipe = CreateRect(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descri
            ingredients: validInts,
            instructions: instructi
            nutritionInfo: nutrition,
            cuisine: cuisiNewlines),
         me,
        Time,
            di
            imageUrl: imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil :wlines),
            
        )
        
        Task {
            let success = aw
            
            await.run {
             se
         
     ess {
 )
 else {
          
                }
            }
        }
    }
}

#Preview {
    // Create a sample recipe for preview
    let sampleRecipe 
        id: "1",
        name: "Sample Recipe",
        description: "A
        ingredients: [
            Ingredient(),
            Ingredient(name: "Ingrep")
        ],
      ,
        nutritionInfo: NutritionInfo(),
 )
}()eStorect(RecipbjentOenvironme        .pleRecipe)
(recipe: samiewEditRecipeV   return  )
    
   23"
 "user1yUserId: eatedB    cr,
    t User"r: "TesByUsereated c     
  "easy"],k", "quic   tags: [   l: nil,
   imageUr    10,
   t: Coun      rating
  4.5,ing: at        avgRium,
.medficulty:  dif   0,
    kTime: 3 coo     
  epTime: 15,   pr,
     Italian": "cuisine       