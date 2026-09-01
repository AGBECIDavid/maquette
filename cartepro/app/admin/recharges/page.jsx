import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "Rechargements" };

export default function Page() {
  return <Shell><AdminSpace section="recharges" /></Shell>;
}
