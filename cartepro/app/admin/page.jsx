import { Shell } from "../../components/Shell.jsx";
import { AdminSpace } from "../../screens/Admin.jsx";

export const metadata = { title: "Tableau de bord national" };

export default function Page() {
  return <Shell><AdminSpace section="bord" /></Shell>;
}
