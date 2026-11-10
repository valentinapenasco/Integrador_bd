import { useEffect, useMemo, useState } from "react";
import { api, getCatalogs } from "./api";

const emptyWine = {
  nombre: "", tipo: "tinto", anada: new Date().getFullYear(), volumen_ml: 750,
  graduacion: 13, precio: 0, cuit_bodega: "", composicion: [{ id_cepa: "", porcentaje: 100 }],
  maridajes: [],
};

function ErrorBox({ error }) {
  return error ? <div className="alert error">{error}</div> : null;
}
function SuccessBox({ message }) {
  return message ? <div className="alert success">{message}</div> : null;
}
function Loading() {
  return <p className="muted">Cargando...</p>;
}
function Button({ children, ...props }) {
  return <button className="button" {...props}>{children}</button>;
}
function Select({ label, value, onChange, children, ...props }) {
  return <label>{label}<select value={value} onChange={onChange} {...props}>{children}</select></label>;
}

function Catalog({ onEdit }) {
  const [wines, setWines] = useState({ items: [], limit: 12, offset: 0 });
  const [filters, setFilters] = useState({ tipo: "", id_cepa: "", bodega: "", anada: "" });
  const [catalogs, setCatalogs] = useState(null);
  const [detail, setDetail] = useState(null);
  const [error, setError] = useState("");
  const load = async (offset = wines.offset) => {
    try {
      setError("");
      const query = new URLSearchParams({ limit: wines.limit, offset });
      Object.entries(filters).forEach(([key, value]) => value && query.set(key, value));
      setWines({ ...(await api(`/vinos?${query}`)), limit: wines.limit, offset });
    } catch (e) { setError(e.message); }
  };
  useEffect(() => { getCatalogs().then(setCatalogs).catch((e) => setError(e.message)); }, []);
  useEffect(() => { load(0); }, []);
  const showDetail = async (id) => {
    try { setError(""); setDetail(await api(`/vinos/${id}`)); } catch (e) { setError(e.message); }
  };
  const editWine = async (id) => {
    try { setError(""); onEdit(await api(`/vinos/${id}`)); } catch (e) { setError(e.message); }
  };
  return <section>
    <h2>Catálogo de vinos</h2>
    <div className="filters">
      <Select label="Tipo" value={filters.tipo} onChange={(e) => setFilters({ ...filters, tipo: e.target.value })}>
        <option value="">Todos</option><option>tinto</option><option>blanco</option><option>rosado</option><option>espumante</option>
      </Select>
      <Select label="Cepa" value={filters.id_cepa} onChange={(e) => setFilters({ ...filters, id_cepa: e.target.value })}>
        <option value="">Todas</option>{catalogs?.cepas.map((c) => <option key={c.id_cepa} value={c.id_cepa}>{c.nombre}</option>)}
      </Select>
      <label>Bodega<input value={filters.bodega} onChange={(e) => setFilters({ ...filters, bodega: e.target.value })} /></label>
      <label>Añada<input type="number" value={filters.anada} onChange={(e) => setFilters({ ...filters, anada: e.target.value })} /></label>
      <Button onClick={() => load(0)}>Buscar</Button>
    </div>
    <ErrorBox error={error} />
    {!wines.items ? <Loading /> : <table><thead><tr><th>Vino</th><th>Tipo</th><th>Añada</th><th>Precio</th><th>Stock total</th><th /></tr></thead>
      <tbody>{wines.items.map((wine) => <tr key={wine.cod_vino}><td>{wine.nombre}</td><td>{wine.tipo}</td><td>{wine.anada}</td><td>${wine.precio}</td><td>{wine.stock_total}</td>
        <td><button className="link" onClick={() => showDetail(wine.cod_vino)}>Detalle</button> <button className="link" onClick={() => editWine(wine.cod_vino)}>Editar</button></td></tr>)}</tbody></table>}
    <div className="pager"><Button disabled={wines.offset === 0} onClick={() => load(Math.max(0, wines.offset - wines.limit))}>Anterior</Button>
      <span>Desde {wines.offset + 1}</span><Button disabled={wines.items?.length < wines.limit} onClick={() => load(wines.offset + wines.limit)}>Siguiente</Button></div>
    {detail && <div className="detail"><button className="close" onClick={() => setDetail(null)}>×</button><h3>{detail.nombre}</h3>
      <p>{detail.tipo} · añada {detail.anada} · ${detail.precio} · stock total: {detail.stock_total}</p>
      <h4>Composición</h4><ul>{detail.cepas.map((c) => <li key={c.id_cepa}>{c.nombre}: {c.porcentaje}%</li>)}</ul>
      <h4>Maridajes</h4><ul>{detail.maridajes.map((m) => <li key={m.id_maridaje}>{m.nombre} ({m.temp_servicio}°)</li>)}</ul>
    </div>}
  </section>;
}

function WineForm({ editing, catalogs, onDone }) {
  const [wine, setWine] = useState(editing ? {
    ...editing, composicion: editing.cepas?.map((c) => ({ id_cepa: c.id_cepa, porcentaje: c.porcentaje })) || [],
    maridajes: editing.maridajes?.map((m) => m.id_maridaje) || [],
  } : { ...emptyWine, cuit_bodega: catalogs.bodegas[0]?.cuit || "", composicion: [{ id_cepa: catalogs.cepas[0]?.id_cepa || "", porcentaje: 100 }] });
  const [error, setError] = useState(""); const [success, setSuccess] = useState("");
  const setField = (field, value) => setWine({ ...wine, [field]: value });
  const request = {
    nombre: wine.nombre,
    tipo: wine.tipo,
    anada: Number(wine.anada),
    volumen_ml: Number(wine.volumen_ml),
    graduacion: Number(wine.graduacion),
    precio: Number(wine.precio),
    cuit_bodega: wine.cuit_bodega,
    composicion: wine.composicion.map((c) => ({
      id_cepa: Number(c.id_cepa),
      porcentaje: Number(c.porcentaje),
    })),
    maridajes: wine.maridajes.map(Number),
  };
  const save = async (event) => {
    event.preventDefault(); setError(""); setSuccess("");
    try {
      const result = await api(editing ? `/vinos/${editing.cod_vino}` : "/vinos", {
        method: editing ? "PUT" : "POST", body: JSON.stringify(request),
      });
      setSuccess(`Vino ${result.nombre} guardado correctamente.`); onDone?.();
    } catch (e) { setError(e.message); }
  };
  const updateComposition = (index, key, value) => setField("composicion", wine.composicion.map((item, i) => i === index ? { ...item, [key]: value } : item));
  return <section><h2>{editing ? "Editar vino" : "Alta de vino"}</h2><form onSubmit={save} className="form-grid">
    <label>Nombre<input required value={wine.nombre} onChange={(e) => setField("nombre", e.target.value)} /></label>
    <Select label="Tipo" value={wine.tipo} onChange={(e) => setField("tipo", e.target.value)}><option>tinto</option><option>blanco</option><option>rosado</option><option>espumante</option></Select>
    <label>Añada<input type="number" required value={wine.anada} onChange={(e) => setField("anada", e.target.value)} /></label>
    <label>Volumen (ml)<input type="number" required value={wine.volumen_ml} onChange={(e) => setField("volumen_ml", e.target.value)} /></label>
    <label>Graduación<input type="number" step="0.01" required value={wine.graduacion} onChange={(e) => setField("graduacion", e.target.value)} /></label>
    <label>Precio<input type="number" step="0.01" required value={wine.precio} onChange={(e) => setField("precio", e.target.value)} /></label>
    <Select label="Bodega" value={wine.cuit_bodega} onChange={(e) => setField("cuit_bodega", e.target.value)}>{catalogs.bodegas.map((b) => <option key={b.cuit} value={b.cuit}>{b.razon_social}</option>)}</Select>
    <fieldset><legend>Composición</legend>{wine.composicion.map((item, index) => <div className="inline" key={index}>
      <select value={item.id_cepa} onChange={(e) => updateComposition(index, "id_cepa", e.target.value)}><option value="">Cepa</option>{catalogs.cepas.map((c) => <option key={c.id_cepa} value={c.id_cepa}>{c.nombre}</option>)}</select>
      <input type="number" step="0.01" value={item.porcentaje} onChange={(e) => updateComposition(index, "porcentaje", e.target.value)} /><button type="button" className="link" onClick={() => setField("composicion", wine.composicion.filter((_, i) => i !== index))}>Quitar</button>
    </div>)}<button type="button" className="link" onClick={() => setField("composicion", [...wine.composicion, { id_cepa: "", porcentaje: 0 }])}>+ Agregar cepa</button></fieldset>
    <fieldset><legend>Maridajes</legend>{catalogs.maridajes.map((m) => <label className="check" key={m.id_maridaje}><input type="checkbox" checked={wine.maridajes.includes(m.id_maridaje)} onChange={(e) => setField("maridajes", e.target.checked ? [...wine.maridajes, m.id_maridaje] : wine.maridajes.filter((id) => id !== m.id_maridaje))} />{m.nombre}</label>)}</fieldset>
    <ErrorBox error={error} /><SuccessBox message={success} /><Button type="submit">Guardar</Button>
  </form></section>;
}

function NewSale({ catalogs }) {
  const [clients, setClients] = useState([]); const [sale, setSale] = useState({ id_cliente: "", id_sala: "", renglones: [{ cod_vino: "", cantidad: 1 }] }); const [result, setResult] = useState(null); const [error, setError] = useState("");
  useEffect(() => { api("/clientes?limit=100").then((r) => setClients(r.items)).catch((e) => setError(e.message)); }, []);
  const addLine = () => setSale({ ...sale, renglones: [...sale.renglones, { cod_vino: "", cantidad: 1 }] });
  const save = async (event) => { event.preventDefault(); setError(""); setResult(null); try { setResult(await api("/comprobantes", { method: "POST", body: JSON.stringify({ ...sale, id_cliente: Number(sale.id_cliente), id_sala: Number(sale.id_sala), renglones: sale.renglones.map((r) => ({ cod_vino: Number(r.cod_vino), cantidad: Number(r.cantidad) })) }) })); } catch (e) { setError(e.message); } };
  return <section><h2>Nueva venta</h2><form onSubmit={save}>
    <div className="form-grid"><Select label="Cliente" value={sale.id_cliente} onChange={(e) => setSale({ ...sale, id_cliente: e.target.value })}><option value="">Seleccione</option>{clients.map((c) => <option key={c.id_cliente} value={c.id_cliente}>{c.razon_social}</option>)}</Select>
      <Select label="Sala" value={sale.id_sala} onChange={(e) => setSale({ ...sale, id_sala: e.target.value })}><option value="">Seleccione</option>{catalogs.salas.map((s) => <option key={s.id_sala} value={s.id_sala}>Sala {s.id_sala} · {s.localidad}</option>)}</Select></div>
    <h3>Renglones</h3>{sale.renglones.map((line, index) => <div className="inline" key={index}><input required type="number" min="1" placeholder="Código de vino" value={line.cod_vino} onChange={(e) => setSale({ ...sale, renglones: sale.renglones.map((r, i) => i === index ? { ...r, cod_vino: e.target.value } : r) })} /><input required type="number" min="1" value={line.cantidad} onChange={(e) => setSale({ ...sale, renglones: sale.renglones.map((r, i) => i === index ? { ...r, cantidad: e.target.value } : r) })} /></div>)}
    <button type="button" className="link" onClick={addLine}>+ Agregar renglón</button><ErrorBox error={error} /><Button type="submit">Registrar venta</Button>
  </form>{result && <div className="result"><SuccessBox message={`Comprobante ${result.nro_comprobante} creado.`} /><strong>Total calculado por el backend: ${result.total}</strong><pre>{JSON.stringify(result.renglones, null, 2)}</pre></div>}</section>;
}

function Transfers({ catalogs }) {
  const [transfer, setTransfer] = useState(null); const [room, setRoom] = useState(""); const [line, setLine] = useState({ cod_vino: "", cantidad: 1 }); const [error, setError] = useState("");
  const action = async (path, options) => {
    try {
      setError("");
      const result = await api(path, options);
      setTransfer((current) => ({
        ...current,
        ...result,
        renglones: result.renglones ?? current?.renglones ?? [],
      }));
    } catch (e) { setError(e.message); }
  };
  const addLine = async () => {
    try {
      setError("");
      await api(`/transferencias/${transfer.nro_transferencia}/renglones`, {
        method: "POST",
        body: JSON.stringify({ cod_vino: Number(line.cod_vino), cantidad: Number(line.cantidad) }),
      });
      setTransfer({ ...transfer, renglones: [...(transfer.renglones || []), { ...line, cod_vino: Number(line.cod_vino), cantidad: Number(line.cantidad) }] });
      setLine({ cod_vino: "", cantidad: 1 });
    } catch (e) { setError(e.message); }
  };
  const create = (e) => { e.preventDefault(); action("/transferencias", { method: "POST", body: JSON.stringify({ id_sala_solicitante: Number(room) }) }); };
  const status = transfer?.estado || "en_confeccion";
  return <section><h2>Transferencias</h2>{!transfer && <form onSubmit={create} className="inline"><Select label="Sala solicitante" name="sala" value={room} onChange={(e) => setRoom(e.target.value)}><option value="">Seleccione</option>{catalogs.salas.map((s) => <option key={s.id_sala} value={s.id_sala}>Sala {s.id_sala} · {s.localidad}</option>)}</Select><Button type="submit" disabled={!room}>Crear transferencia</Button></form>}
    {transfer && <div className="panel"><h3>Transferencia {transfer.nro_transferencia}</h3><p>Estado: <strong>{status}</strong></p>{transfer.renglones?.length > 0 && <ul>{transfer.renglones.map((item, index) => <li key={`${item.cod_vino}-${index}`}>Vino {item.cod_vino}: {item.cantidad} unidades</li>)}</ul>}{status === "en_confeccion" && <><div className="inline"><input type="number" min="1" placeholder="Código de vino" value={line.cod_vino} onChange={(e) => setLine({ ...line, cod_vino: e.target.value })} /><input type="number" min="1" value={line.cantidad} onChange={(e) => setLine({ ...line, cantidad: e.target.value })} /><Button onClick={addLine}>Agregar</Button></div><Button disabled={!transfer.renglones?.length} onClick={() => action(`/transferencias/${transfer.nro_transferencia}/terminar`, { method: "POST" })}>Terminar confección</Button></>}{status === "terminado" && <Button onClick={() => action(`/transferencias/${transfer.nro_transferencia}/procesar`, { method: "POST" })}>Procesar transferencia</Button>}<Button onClick={() => setTransfer(null)}>Nueva transferencia</Button></div>}<ErrorBox error={error} /></section>;
}

function Dashboard({ catalogs }) {
  const [data, setData] = useState({ top: [], rooms: [], without: [] }); const [room, setRoom] = useState(""); const [error, setError] = useState("");
  useEffect(() => { Promise.all([api("/reportes/top-vinos?limit=10"), api("/reportes/ventas-por-sala")]).then(([top, rooms]) => setData((d) => ({ ...d, top, rooms }))).catch((e) => setError(e.message)); }, []);
  useEffect(() => { if (room) api(`/reportes/vinos-sin-stock?id_sala=${room}`).then((without) => setData((d) => ({ ...d, without }))).catch((e) => setError(e.message)); }, [room]);
  const max = useMemo(() => Math.max(...data.rooms.map((r) => Number(r.monto_neto)), 1), [data.rooms]);
  return <section><h2>Tablero</h2><ErrorBox error={error} /><div className="dashboard"><div className="card"><h3>Top vinos vendidos</h3><ol>{data.top.map((v) => <li key={v.cod_vino}>{v.nombre} — {v.botellas_vendidas} botellas</li>)}</ol></div><div className="card"><h3>Ventas por sala · último trimestre</h3>{data.rooms.map((r) => <div className="bar-row" key={r.id_sala}><span>Sala {r.id_sala}</span><div className="bar" style={{ width: `${Number(r.monto_neto) / max * 100}%` }} /> <b>${r.monto_neto}</b></div>)}</div><div className="card"><Select label="Vinos sin stock local" value={room} onChange={(e) => setRoom(e.target.value)}><option value="">Seleccione sala</option>{catalogs.salas.map((s) => <option key={s.id_sala} value={s.id_sala}>Sala {s.id_sala} · {s.localidad}</option>)}</Select>{!room ? <p className="muted">Seleccione una sala para consultar.</p> : data.without.length === 0 ? <p className="muted">No hay vinos sin stock local con stock disponible en el depósito.</p> : <ul>{data.without.map((v) => <li key={v.cod_vino}>{v.nombre}: sala {v.stock_sala}, depósito {v.stock_deposito}</li>)}</ul>}</div></div></section>;
}

export default function App() {
  const [page, setPage] = useState("catalog"); const [catalogs, setCatalogs] = useState(null); const [editing, setEditing] = useState(null); const [error, setError] = useState("");
  useEffect(() => { getCatalogs().then(setCatalogs).catch((e) => setError(e.message)); }, []);
  return <><header><div><h1>Bodegas del Atuel</h1><p>Gestión vitivinícola</p></div><nav>{[["catalog", "Catálogo"], ["wine", "Alta / edición"], ["sale", "Nueva venta"], ["transfer", "Transferencias"], ["dashboard", "Tablero"]].map(([key, label]) => <button key={key} className={page === key ? "active" : ""} onClick={() => { setPage(key); setEditing(null); }}>{label}</button>)}</nav></header><main><ErrorBox error={error} />{!catalogs ? <Loading /> : page === "catalog" ? <Catalog onEdit={(wine) => { setEditing(wine); setPage("wine"); }} /> : page === "wine" ? <WineForm editing={editing} catalogs={catalogs} onDone={() => setPage("catalog")} /> : page === "sale" ? <NewSale catalogs={catalogs} /> : page === "transfer" ? <Transfers catalogs={catalogs} /> : <Dashboard catalogs={catalogs} />}</main></>;
}
