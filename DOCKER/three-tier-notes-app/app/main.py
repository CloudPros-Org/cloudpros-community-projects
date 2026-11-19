import os
from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

import models
from database import engine, get_db

# Automatically creates the 'notes' table in PostgreSQL if it doesn't exist yet
models.Base.metadata.create_all(bind=engine)

app = FastAPI()


class NoteCreate(BaseModel):
  content: str


# 1. CREATE: Add a new note to PostgreSQL
@app.post("/notes", status_code=201)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
  new_note = models.Note(content=note.content)
  db.add(new_note)
  db.commit()
  db.refresh(new_note)
  return new_note


# 2. READ ALL: Fetch all notes from PostgreSQL
@app.get("/notes")
def get_all_notes(db: Session = Depends(get_db)):
  return db.query(models.Note).all()


# 3. READ ONE: Fetch a single note by its ID
@app.get("/notes/{note_id}")
def get_note(note_id: int, db: Session = Depends(get_db)):
  note = db.query(models.Note).filter(models.Note.id == note_id).first()
  if not note:
    raise HTTPException(status_code=404, detail="Note not found")
  return note


# 4. UPDATE: Edit an existing note in PostgreSQL
@app.put("/notes/{note_id}")
def update_note(
    note_id: int, updated_note: NoteCreate, db: Session = Depends(get_db)
):
  note = db.query(models.Note).filter(models.Note.id == note_id).first()
  if not note:
    raise HTTPException(status_code=404, detail="Note not found")
  note.content = updated_note.content
  db.commit()
  db.refresh(note)
  return note


# 5. DELETE: Remove a note from PostgreSQL
@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int, db: Session = Depends(get_db)):
  note = db.query(models.Note).filter(models.Note.id == note_id).first()
  if not note:
    raise HTTPException(status_code=404, detail="Note not found")
  db.delete(note)
  db.commit()
  return


print(os.listdir())
