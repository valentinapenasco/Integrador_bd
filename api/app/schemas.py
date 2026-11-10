from decimal import Decimal
from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field

Identifier = Annotated[int, Field(gt=0)]


class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CompositionInput(InputModel):
    id_cepa: Identifier
    porcentaje: Decimal


class WineInput(InputModel):
    nombre: str = Field(min_length=1, max_length=100)
    tipo: Literal["tinto", "blanco", "rosado", "espumante"]
    anada: int
    volumen_ml: int
    graduacion: Decimal
    precio: Decimal
    cuit_bodega: str = Field(pattern=r"^\d{11}$")
    composicion: list[CompositionInput] = Field(min_length=1)
    maridajes: list[Identifier] = Field(default_factory=list)


class ClientBase(InputModel):
    razon_social: str = Field(min_length=1, max_length=150)
    tipo_doc: str = Field(min_length=1, max_length=10)
    nro_doc: str = Field(min_length=1, max_length=50)
    direccion: str = Field(min_length=1, max_length=200)
    localidad: str = Field(min_length=1, max_length=100)


class SocioInput(ClientBase):
    tipo_cliente: Literal["socio"]


class DistribuidorInput(ClientBase):
    tipo_cliente: Literal["distribuidor"]
    zona_cobertura: str = Field(min_length=1, max_length=150)
    nro_habilitacion: str = Field(min_length=1, max_length=50)


class ExportadorInput(ClientBase):
    tipo_cliente: Literal["exportador"]
    pais_destino: str = Field(min_length=1, max_length=100)


ClientInput = Annotated[
    Union[SocioInput, DistribuidorInput, ExportadorInput],
    Field(discriminator="tipo_cliente"),
]


class SaleLineInput(InputModel):
    cod_vino: Identifier
    cantidad: int


class ReceiptInput(InputModel):
    id_cliente: Identifier
    id_sala: Identifier
    renglones: list[SaleLineInput] = Field(min_length=1)


class TransferInput(InputModel):
    id_sala_solicitante: Identifier


class IngressInput(InputModel):
    cod_transportista: Identifier
    cuit_bodega: str = Field(pattern=r"^\d{11}$")


class DocumentLineInput(InputModel):
    cod_vino: Identifier
    cantidad: int
