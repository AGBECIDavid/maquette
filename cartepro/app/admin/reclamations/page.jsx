import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "Réclamations" };

export default function Page() {
  return <Shell><AdminSpace section="reclamations" /></Shell>;
}
