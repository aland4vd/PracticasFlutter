
import os
import shutil
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from pydantic import BaseModel, ConfigDict

from sqlalchemy import create_engine, Column, Integer, String, TIMESTAMP, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session


# CONEXION A MYSQL
DATABASE_URL = "mysql+pymysql://root:@localhost/blog_db"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


# ESQUEMA SQLALCHEMY
class FotoDB(Base):
    __tablename__ = "fotos"

    id_foto = Column(Integer, primary_key=True, index=True, autoincrement=True)
    descripcion = Column(String(255), nullable=False)
    ruta = Column(String(255), nullable=False)
    fecha_subida = Column(
        TIMESTAMP,
        nullable=False,
        server_default=text('CURRENT_TIMESTAMP')
    )


# ESQUEMA PYDANTIC
class FotoSchema(BaseModel):
    id_foto: int
    descripcion: str
    ruta: str
    fecha_subida: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)


class FotoResponsive(BaseModel):
    msg: str
    foto: FotoSchema


# INICIALIZAR LA APP Y CONFIGURAR CORS
app = FastAPI(
    title="API Gestión de Imágenes",
    description="Práctica 10"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"]
)


# CREAR CARPETA UPLOADS
UPLOAD_DIR = "uploads"

os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOAD_DIR),
    name="uploads"
)


# CONSEGUIR SESION DE DB
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ENDPOINTS

# SUBIR FOTOGRAFIA
@app.post("/fotos", response_model=FotoResponsive)
async def subir_foto(
    descripcion: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):

    # Guardar el archivo en la carpeta uploads
    ruta_archivo = f"{UPLOAD_DIR}/{file.filename}"

    try:
        with open(ruta_archivo, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al guardar el archivo: {str(e)}"
        )

    # Guardar la informacion en la base de datos
    nueva_foto = FotoDB(
        descripcion=descripcion,
        ruta=ruta_archivo
    )

    db.add(nueva_foto)
    db.commit()
    db.refresh(nueva_foto)

    return {
        "msg": "Foto subida exitosamente",
        "foto": nueva_foto
    }


# LISTAR Y OBTENER TODAS LAS FOTOS
@app.get("/fotos", response_model=List[FotoSchema])
def listar_fotos(db: Session = Depends(get_db)):

    fotos = db.query(FotoDB).all()

    return fotos
