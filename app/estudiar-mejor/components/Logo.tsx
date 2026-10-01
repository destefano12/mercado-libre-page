/**
 * El logo de Estudiar Mejor: seis aspas girando alrededor de un centro vacío,
 * tres llenas y tres más tenues entre medio.
 */
export function Logo({
  tamaño = 48,
  tono = "#5FD3AE",
  className = "",
}: {
  tamaño?: number;
  tono?: string;
  className?: string;
}) {
  const llena = "M0 -7 C 11 -16 17 -30 14 -44 C 2 -37 -4 -23 0 -7 Z";
  const tenue = "M0 -9 C 8 -16 12 -27 10 -37 C 1 -31 -3 -21 0 -9 Z";

  return (
    <svg
      width={tamaño}
      height={tamaño}
      viewBox="0 0 100 100"
      fill="none"
      aria-hidden="true"
      className={className}
    >
      <g transform="translate(50 50)">
        {[0, 120, 240].map((giro) => (
          <path key={`llena-${giro}`} transform={`rotate(${giro})`} d={llena} fill={tono} />
        ))}
        {[60, 180, 300].map((giro) => (
          <path key={`tenue-${giro}`} transform={`rotate(${giro})`} d={tenue} fill={tono} opacity="0.42" />
        ))}
      </g>
    </svg>
  );
}

/** El logo dentro de su placa, como ícono de la aplicación. */
export function LogoEnPlaca({ lado = 32, className = "" }: { lado?: number; className?: string }) {
  return (
    <span
      className={`grid shrink-0 place-items-center rounded-md bg-marca-fondo ${className}`}
      style={{ width: lado, height: lado }}
    >
      <Logo tamaño={Math.round(lado * 0.78)} />
    </span>
  );
}
